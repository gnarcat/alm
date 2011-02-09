# $HeadURL: http://ambraproject.org/svn/plos/alm/head/lib/tasks/source_config.rake $
# $Id: source_config.rake 5693 2010-12-03 19:09:53Z josowski $
#
# Copyright (c) 2009-2010 by Public Library of Science, a non-profit corporation
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

require 'doi'

namespace :db do
  desc "Show configured sources"
  task :source_config => :environment do
    Source.all.each do |s|
      puts "#{s.name}#{" (inactive)" unless s.active}:"
      puts "  URL: '#{s.url}'" if s.uses_url
      puts "  Username: '#{s.username}'" if s.uses_username
      puts "  Password: '#{s.password}'" if s.uses_password
      puts "  Staleness between updates: #{s.staleness_days} days\n"
    end
  end
end