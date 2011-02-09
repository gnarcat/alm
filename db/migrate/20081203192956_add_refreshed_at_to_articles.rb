# $HeadURL: http://ambraproject.org/svn/plos/alm/head/db/migrate/20081203192956_add_refreshed_at_to_articles.rb $
# $Id: 20081203192956_add_refreshed_at_to_articles.rb 5693 2010-12-03 19:09:53Z josowski $
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

class AddRefreshedAtToArticles < ActiveRecord::Migration
  def self.up
    add_column :articles, :refreshed_at, :datetime, :default => DateTime.new(1970), 
      :null => false
  end

  def self.down
    remove_column :articles, :refreshed_at
  end
end