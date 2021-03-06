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

class Nature < Source
  SECONDS_IN_A_DAY = 86400
  BATCH_SIZE = 1000

  validates_each :url, :api_key do |record, attr, value|
    record.errors.add(attr, "can't be blank") if value.blank?
  end

  def get_data(article, options={})
    raise(ArgumentError, "#{display_name} configuration requires an api key") \
      if config.api_key.blank?

    query_url = get_query_url(article)

    begin
      results = get_json(query_url, options)
    rescue => e
      Rails.logger.error("#{display_name} #{e.message}")
      if e.respond_to?('response')
        if e.response.kind_of?(Net::HTTPForbidden)
          # http response 403
          Rails.logger.error "#{display_name} returned 403, they might be throttling us."
        end
      end
      raise e
    end

    events = results.map do |result|
      url = result['post']['url']
      url = "http://#{url}" unless url.start_with?("http://")

      {:event => result['post'], :event_url => url}
    end

    {:events => events, :event_count => events.length}
  end

  def queue_articles

    # assumptions
    # requests per day is smaller than the total number of articles in the application
    # requests per day is smaller than total number of seconds in 1 day

    batch_time_interval = SECONDS_IN_A_DAY

    # determine if the source is active
    if active
      queue_job = true

      # determine if the source is disabled or not
      unless self.disable_until.nil?
        queue_job = false

        if self.disable_until < Time.zone.now
          self.disable_until = nil
          save
          queue_job = true
        end
      end

      if queue_job
        queue_article_jobs
      end
    end

    return batch_time_interval
  end

  def queue_article_jobs
    # figure out when the next job should be scheduled
    job = Delayed::Job.where("queue = 'nature'").select('run_at').order('run_at DESC').limit(1)
    run_at = Time.zone.now
    if job.length > 0
      run_at = job[0].run_at
    end

    limit = BATCH_SIZE
    offset = 0

    while offset < requests_per_day
      # find articles that need to be updated
      # not queued currently
      # stale from updated_at
      rs = retrieval_statuses.published.
          order('retrieved_at DESC').
          limit(limit).
          offset(offset).
          pluck("retrieval_statuses.id")  
      Rails.logger.debug "#{name} total article queued #{rs.length}"

      rs.each do | rs_id |
        run_at += SECONDS_IN_A_DAY / requests_per_day
        Delayed::Job.enqueue SourceJob.new(rs_id, id), :queue => name, :run_at => run_at
      end

      offset += limit
    end
  end

  def get_query_url(article)
    config.url % { :api_key => config.api_key, :doi => CGI.escape(article.doi) }
  end

  def get_config_fields
    [{:field_name => "url", :field_type => "text_area", :size => "90x2"},
     {:field_name => "api_key", :field_type => "text_field"}]
  end

  def url
    config.url
  end

  def url=(value)
    config.url = value
  end

  def api_key
    config.api_key
  end

  def api_key=(value)
    config.api_key = value
  end
  
end