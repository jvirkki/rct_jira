#
#  Copyright 2013-2014 Jyri J. Virkki <jyri@virkki.com>
#
#  This file is part of rct_jira.
#
#  rct_jira is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  rct_jira is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with rct_jira.  If not, see <http://www.gnu.org/licenses/>.
#


# Implements an rct client for JIRA APIs.
#
# Only a tiny subset supported. Expand as needed.
#
# https://developer.atlassian.com/display/JIRADEV/JIRA+REST+API+Tutorials
# https://docs.atlassian.com/jira/REST/latest/
#


require 'rct_client'

class Jira < RCTClient

  BASE_PATH = '/rest/api/2'


  #----------------------------------------------------------------------------
  # CLI definition. Used by the rct framework to determine what CLI commands
  # are available here.
  #
  def cli
    return {
      'server_info' => ServerInfo,
      'not_watching' => NotWatching,
      'add_my_watch' => AddMyWatch,
      'watch_category' => WatchCategory,
      'mine' => Mine
    }
  end


  #----------------------------------------------------------------------------
  # Retrieve server info (really only useful to test API/connection).
  # No authentication required.
  #
  # https://docs.atlassian.com/jira/REST/latest/#idp1713744
  #
  # Required: none
  # Optional: none
  # Saves to state: nothing
  #
  ServerInfo = {
    'required' => { },
    'optional' => { }
  }

  def server_info
    ssettmp(SERVER_PROTOCOL, 'https')
    ssettmp(REQ_METHOD, 'GET')
    ssettmp(REQ_PATH, "#{BASE_PATH}/serverInfo")
    yield
  end


  #----------------------------------------------------------------------------
  # Retrieve a list of issues which I (user authenticating) am not watching.
  #
  # Note this may not be a full list of unwatched issues if the list is larger
  # than the limit, which defaults to 100. The server may also impose a limit
  # which might be smaller than the requested limit.
  #
  # Required:
  #     username : Authenticate as this user.
  #     password : Password of username.
  #     project : JIRA project name to search.
  # Optional:
  #     limit : Return up to this many results (default: 100)
  # Saves to state:
  #     not_watching_result : Hash of key => description of all issues found
  #
  NotWatching = {
    'required' => {
      'username' => [ '-u', '--user', 'User name' ],
      'password' => [ '-P', '--password', 'Password' ],
      'project' => [ '-c' , '--project', 'Project name (category)' ],
    },
    'optional' => {
      'limit' => [ '-l', '--limit', 'Limit result set size to this number'],
    }
  }

  def not_watching
    user = sget('username')
    password = sget('password')
    project = sget('project')

    limit = sget('limit')
    limit = '100' if (limit == nil)

    ssettmp(SERVER_PROTOCOL, 'https')
    ssettmp(REQ_METHOD, 'GET')
    ssettmp(REQ_AUTH_TYPE, REQ_AUTH_TYPE_BASIC)
    ssettmp(REQ_AUTH_NAME, user)
    ssettmp(REQ_AUTH_PWD, password)
    ssettmp(REQ_PATH, "#{BASE_PATH}/search")

    params = add_param(nil, 'maxResults', limit)
    params = add_param(params, 'fields', 'summary')
    params = add_param(params, 'jql',
                       "project=#{project} and watcher != currentUser()")
    ssettmp(REQ_PARAMS, params)

    result = yield

    if (result.ok)
      # On success, create a simple key->description hash with the results
      if (is_cli) then cli_output = "\n" end
      unwatched = Hash.new()
      json = JSON.parse(result.body)

      issues = json['issues']
      if (issues != nil)
        issues.each { |h|
          key = h['key']
          summary = h['fields']['summary']
          unwatched[key] = summary
          if (is_cli) then cli_output += "#{key} : #{summary}\n" end
        }
      end

      sset('not_watching_result', unwatched)
      if (is_cli)
        sset(CLI_OUTPUT, cli_output)
      end
    end

    return result
  end


  #----------------------------------------------------------------------------
  # Retrieve a list of issues which I (user authenticating) own.
  #
  # Note this may not be a full list of if the list is larger than the
  # limit, which defaults to 100. The server may also impose a limit
  # which might be smaller than the requested limit.
  #
  # Required:
  #     username : Authenticate as this user.
  #     password : Password of username.
  # Optional:
  #     limit   : Return up to this many results (default: 100)
  #     project : Limit results to this project.
  # Saves to state:
  #     my_bugs : Hash of key => description of all issues found
  #
  Mine = {
    'required' => {
      'username' => [ '-u', '--user', 'User name' ],
      'password' => [ '-P', '--password', 'Password' ],
    },
    'optional' => {
      'limit' => [ '-l', '--limit', 'Limit result set size to this number'],
      'project' => [ '-c' , '--project', 'Project name (category)' ],
    }
  }

  def mine
    user = sget('username')
    password = sget('password')
    project = sget('project')

    limit = sget('limit')
    limit = '100' if (limit == nil)

    ssettmp(SERVER_PROTOCOL, 'https')
    ssettmp(REQ_METHOD, 'GET')
    ssettmp(REQ_AUTH_TYPE, REQ_AUTH_TYPE_BASIC)
    ssettmp(REQ_AUTH_NAME, user)
    ssettmp(REQ_AUTH_PWD, password)
    ssettmp(REQ_PATH, "#{BASE_PATH}/search")

    params = add_param(nil, 'maxResults', limit)
    params = add_param(params, 'fields', 'summary')

    jql = ""
    if (project != nil)
      jql = "project=#{project} AND "
    end
    jql = "#{jql}assignee = currentUser() AND (status=\"Open\" OR status=\"In Progress\")"

    params = add_param(params, 'jql', jql)
    ssettmp(REQ_PARAMS, params)

    result = yield

    if (result.ok)
      # On success, create a simple key->description hash with the results
      if (is_cli) then cli_output = "\n" end
      list = Hash.new()
      json = JSON.parse(result.body)
      issues = json['issues']
      issues.each { |h|
        key = h['key']
        summary = h['fields']['summary']
        list[key] = summary
        if (is_cli) then cli_output += "#{key} : #{summary}\n" end
      }
      sset('my_bugs', list)
      if (is_cli)
        sset(CLI_OUTPUT, cli_output)
      end
    end

    return result
  end


  #----------------------------------------------------------------------------
  # Add myself as a watcher to one issue.
  #
  # https://docs.atlassian.com/jira/REST/latest/#idp1831280
  #
  # Required:
  #     username : Authenticate as this user.
  #     password : Password of username.
  #     project : JIRA project name to search.
  #     key : JIRA issue key to update.
  # Optional:
  #     none
  # Saves to state:
  #     nothing
  #
  AddMyWatch = {
    'required' => {
      'username' => [ '-u', '--user', 'User name' ],
      'password' => [ '-P', '--password', 'Password' ],
      'project' => [ '-c' , '--project', 'Project name (category)' ],
      'key' => [ '-k', '--issuekey', 'Issue to add myself as watcher'],
    },
    'optional' => { }
  }

  def add_my_watch
    user = sget('username')
    password = sget('password')
    project = sget('project')
    key = sget('key')

    ssettmp(SERVER_PROTOCOL, 'https')
    ssettmp(REQ_METHOD, 'POST')
    ssettmp(REQ_AUTH_TYPE, REQ_AUTH_TYPE_BASIC)
    ssettmp(REQ_AUTH_NAME, user)
    ssettmp(REQ_AUTH_PWD, password)
    ssettmp(REQ_PATH, "#{BASE_PATH}/issue/#{key}/watchers")
    ssettmp(REQ_BODY, "\"#{user}\"")

    headers = Hash.new()
    headers['Content-type'] = 'application/json'
    ssettmp(REQ_HEADERS, headers)

    result = yield

    if (result.status == 204)
      if (is_cli)
        sset(CLI_OUTPUT, "Added #{user} as a watcher to #{key}")
      end
    else
      result.add_error("Unable to add #{user} to #{key}")
    end

    return result
  end


  #----------------------------------------------------------------------------
  # Add myself as a watcher to all unwatched issues in a given category.
  #
  # This is a wrapper function which combines NotWatching and AddMyWatch
  # for convenience.
  #
  # Note this may not be able to add me to all unwatched issues if there
  # are more than the server list limit. In that case one may need to run
  # this multiple times.
  #
  # Required:
  #     username : Authenticate as this user.
  #     password : Password of username.
  #     project : JIRA project name to watch.
  # Optional:
  #     none
  # Saves to state:
  #     nothing
  #
  WatchCategory = {
    'required' => {
      'username' => [ '-u', '--user', 'User name' ],
      'password' => [ '-P', '--password', 'Password' ],
      'project' => [ '-c' , '--project', 'Project name (category)' ],
    },
    'optional' => { }
  }

  def watch_category

    project = sget('project')

    # Pretend we're not in CLI mode even if we are to avoid duplicate output
    # from the functions we're wrapping.

    mode = RCT.sget(RCT_MODE)
    RCT.sdelete(RCT_MODE)

    result = not_watching { $HTTP.handle_request() }
    if (!result.ok)
      result.add_error("Unable to get list of unwatched issues")
      RCT.sset(RCT_MODE, mode)
      return result
    end

    issues = RCT.sget('not_watching_result')
    count = 0

    issues.each { |key, desc|
      RCT.log(RESULT, "#{key}: #{desc}")
      RCT.sset('key', key)
      result = add_my_watch { $HTTP.handle_request() }
      if (!result.ok)
        result.add_error("Unable to add watcher to #{key}")
        RCT.sset(RCT_MODE, mode)
        return result
      end
      count = count + 1
    }

    RCT.sset(RCT_MODE, mode)
    if (is_cli)
      sset(CLI_OUTPUT, "Added #{count} bugs to watch in #{project}")
    end

    return result
  end


end
