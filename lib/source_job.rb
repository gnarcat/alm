# $HeadURL$
# $Id$
#
# Copyright (c) 2009-2012 by Public Library of Science, a non-profit corporation
# http://www.plos.org/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'source_helper'
require 'timeout'

class SourceJob < Struct.new(:rs_ids, :source_id)
  include SourceHelper

  def enqueue(job)
    Rails.logger.debug "enqueue #{rs_ids.inspect}"

    # keep track of when the article was queued up
    RetrievalStatus.update_all(["queued_at = ?", Time.zone.now], ["id in (?)", rs_ids] )
  end

  def perform

    # check to see if source is active or not
    source = Source.find(source_id)
    unless source.active
      Rails.logger.info "#{source.name} not active.  Exiting the job"
      return
    end

    srand
    #time to sleep between failures
    sleep_time = 0

    # just in case a worker gets stuck
    Timeout.timeout(Delayed::Worker.max_run_time) do
      # wait till the source isn't disabled
      while not (source.disable_until.nil? || source.disable_until < Time.zone.now)
        Rails.logger.info "#{source.name} is disabled.  Sleep for #{source.disable_delay} seconds."
        sleep(source.disable_delay)
      end

      rs_ids.each do | rs_id |
        begin
          perform_get_data(rs_id, source)
        rescue => e
          Rails.logger.error "retrieval_status id: #{rs_id}, source id: #{source_id} failed to get data. \n#{e.message} \n#{e.backtrace.join("\n")}"
          # each time we fail to get an answer from a source, wait longer
          # and wait random amount of time
          sleep_time += source.disable_delay + rand(source.disable_delay)
          Rails.logger.info "Sleep for #{sleep_time} seconds"
          sleep(sleep_time)
        end
      end
    end

  end

  def perform_get_data(rs_id, source)

    rs = RetrievalStatus.find(rs_id)

    article = Article.find(rs.article_id)

    rh = RetrievalHistory.new
    rh.retrieval_status_id = rs.id
    rh.article_id = rs.article_id
    rh.source_id = source.id
    rh.save

    Rails.logger.debug "#{source.name} #{article.doi} perform"

    begin
      event_count = 0

      data_from_source = source.get_data(article, {:retrieval_status => rs, :timeout => source.timeout })
      if data_from_source.class == Hash
        events = data_from_source[:events]
        events_url = data_from_source[:events_url]
        event_count = data_from_source[:event_count]
        local_id = data_from_source[:local_id]
        attachment = data_from_source[:attachment]
      end

      retrieved_at = Time.zone.now
      if event_count > 0
        data = {}
        data[:doi] = article.doi
        data[:retrieved_at] = retrieved_at
        data[:source] = source.name
        data[:events] = events
        data[:events_url] = events_url
        data[:doc_type] = "current"

        if !attachment.nil?

          if !attachment[:filename].nil? && !attachment[:content_type].nil? && !attachment[:data].nil?
            data[:_attachments] = {attachment[:filename] => {"content_type" => attachment[:content_type],
                                                             "data" => Base64.encode64(attachment[:data]).gsub(/\n/, '')}}
          end
        end

        # save the data to couchdb
        data_rev = save_alm_data(rs.data_rev, data.clone, "#{source.name}:#{CGI.escape(article.doi)}")
        rs.data_rev = data_rev
        rs.event_count = event_count
        unless local_id.nil?
          rs.local_id = local_id
        end

        #TODO change this to a copy
        data.delete(:_attachments)
        data[:doc_type] = "history"
        # save the data to couchdb as retrieval history data
        save_alm_data(nil, data, rh.id)

        # set retrieval history status to success
        rh.status = RetrievalHistory::SUCCESS_MSG
        # save the event count in mysql
        rh.event_count = event_count

      else
        rs.event_count = 0
        rs.data_rev = nil

        # if we don't get any data, set retrieval history status to success with no data
        rh.status = RetrievalHistory::SUCCESS_NODATA_MSG
        rh.event_count = 0
      end

      rs.retrieved_at = retrieved_at
      rs.scheduled_at = rs.stale_at
      rh.retrieved_at = retrieved_at

      rs.save
      rh.save
    rescue => e
      Rails.logger.error "retrieval_status id: #{rs_id}, source id: #{source_id} failed to get data. \n#{e.message} \n#{e.backtrace.join("\n")}"

      rh.retrieved_at = Time.zone.now
      rh.status = RetrievalHistory::ERROR_MSG
      rh.save

      raise e
    end

  end

  def error(job, exception)
    Rails.logger.error "job error #{exception.message} \n#{exception.backtrace.join("\n")}"
  end

  def after(job)
    Rails.logger.debug "job completed"

    #reset the queued at value
    RetrievalStatus.update_all(["queued_at = ?", nil], ["id in (?)", rs_ids] )
  end

end

