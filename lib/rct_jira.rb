#
#  Copyright 2013-2022 Jyri J. Virkki <jyri@virkki.com>
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
  # Class description, for automated help.
  #
  def description
    "The RCT Jira class implements access to some of the common Jira\n" +
    "(http://en.wikipedia.org/wiki/JIRA) APIs."
  end


  #----------------------------------------------------------------------------
  # CLI definition. Used by the rct framework to determine what CLI
  # commands are available here. This maps the operation name to a
  # Hash of info about that operation.
  #
  # Note that this needs to list only those operations which can be
  # invoked in CLI mode. Not all operations supported by an rct client
  # module are necessarily CLI-compatible so this may be a subset of
  # the operations available here.
  #
  def cli
    return {
      'server_info' => ServerInfo,
      'not_watching' => NotWatching,
      'add_my_watch' => AddMyWatch,
      'watch_category' => WatchCategory,
      'mine' => Mine,
      'create_meta' => CreateMeta,
      'create_from_data' => CreateIssueFromTemplate,
      'get_issue' => GetIssue,
      'recent' => GetRecent
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
    'description' => "Retrieve server info (mainly for testing connection)",
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
    'description' => "Retrieve list of issues I am not watching",
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
    'description' => "Retrieve list of issues I own",
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
    'description' => "Add myself as a watcher to one issue",
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
    'description' => "Add myself as a watcher to all issues in category",
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


  #----------------------------------------------------------------------------
  # Retrieve metadata required for issues.
  #
  # Required:
  #     username : Authenticate as this user.
  #     password : Password of username.
  #     project  : JIRA project name to search.
  # Optional:
  #     issues   : Issue type or comma-separated list of types to query.
  # Saves to state:
  #
  #
  CreateMeta = {
    'description' => "Retrieve metadata related to creating issues",
    'required' => {
      'username' => [ '-u', '--user', 'User name' ],
      'password' => [ '-P', '--password', 'Password' ],
      'project' => [ '-c' , '--project', 'Project name (category)' ],
    },
    'optional' => {
      'issues' => [ '-I', '--issues', 'Issue type or comma-separated list'],
    }
  }

  def create_meta
    user = sget('username')
    password = sget('password')
    project = sget('project')
    issues = sget('issues')

    ssettmp(SERVER_PROTOCOL, 'https')
    ssettmp(REQ_METHOD, 'GET')
    ssettmp(REQ_AUTH_TYPE, REQ_AUTH_TYPE_BASIC)
    ssettmp(REQ_AUTH_NAME, user)
    ssettmp(REQ_AUTH_PWD, password)
    ssettmp(REQ_PATH, "#{BASE_PATH}/issue/createmeta")

    params = add_param(nil, 'issuetypeNames', issues)
    params = add_param(params, 'expand', 'projects.issuetypes.fields')
    ssettmp(REQ_PARAMS, params)

    result = yield

    if (result.ok)
      # On success, create a simple key->description hash with the results
      if (is_cli) then cli_output = "\n" end
      json = JSON.parse(result.body)

      if (is_cli)
        sset(CLI_OUTPUT, cli_output)
      end
    end

    return result
  end


  #----------------------------------------------------------------------------
  # Create a new issue based from a template file.
  #
  # https://developer.atlassian.com/cloud/jira/platform/rest/v2/api-group-issues/#api-rest-api-2-issue-post
  #
  # Required:
  #     username : Authenticate as this user.
  #     password : Password of username.
  #     data     : JSON body with required data (see URL above)
  #
  # Optional:
  #
  # Saves to state:
  #
  CreateIssueFromTemplate = {
    'description' => "Create a new issue based on a template file",
    'required' => {
      'username' => [ '-u', '--user', 'User name' ],
      'password' => [ '-P', '--password', 'Password' ],
      'body' => [ '-d' , '--data', 'JSON body' ],
    },
    'optional' => {
    }
  }

  def create_from_data
    user = sget('username')
    password = sget('password')
    datafile = sget('body')

    ssettmp(SERVER_PROTOCOL, 'https')
    ssettmp(REQ_METHOD, 'POST')
    ssettmp(REQ_AUTH_TYPE, REQ_AUTH_TYPE_BASIC)
    ssettmp(REQ_AUTH_NAME, user)
    ssettmp(REQ_AUTH_PWD, password)
    ssettmp(REQ_PATH, "#{BASE_PATH}/issue")

    if (!File.exists?(datafile))
      puts "error: #{datafile} does not exist"
      exit(1)
    end

    data = File.read(datafile)
    ssettmp(REQ_BODY, data)

    result = yield

    if (result.ok)
      # On success, create a simple key->description hash with the results
      if (is_cli) then cli_output = "\n" end
      json = JSON.parse(result.body)

#      sset('not_watching_result', unwatched)
      if (is_cli)
        sset(CLI_OUTPUT, cli_output)
      end
    end

    return result
  end


  #----------------------------------------------------------------------------
  # Retrieve one issue.
  #
  # Required:
  #     username : Authenticate as this user.
  #     password : Password of username.
  #     key      : Issue key.
  # Saves to state:
  #     get_issue_result : Hash of key => value of selected fields.
  #
  GetIssue = {
    'description' => "Retrieve one issue",
    'required' => {
      'username' => [ '-u', '--user', 'User name' ],
      'password' => [ '-P', '--password', 'Password' ],
      'key' => [ '-k' , '--key', 'Issue key' ],
    },
    'optional' => {
    }
  }

  def get_issue
    user = sget('username')
    password = sget('password')
    key = sget('key')

    ssettmp(SERVER_PROTOCOL, 'https')
    ssettmp(REQ_METHOD, 'GET')
    ssettmp(REQ_AUTH_TYPE, REQ_AUTH_TYPE_BASIC)
    ssettmp(REQ_AUTH_NAME, user)
    ssettmp(REQ_AUTH_PWD, password)
    ssettmp(REQ_PATH, "#{BASE_PATH}/issue/#{key}")

    fields = "issuetype,created,priority,status,summary,updated," +
             "statuscategorychangedate,labels,components"
    params = add_param(nil, 'fields', fields)
    ssettmp(REQ_PARAMS, params)

    result = yield

    if (result.status == 200)
      # On success, create a simple key->description hash with the results
      if (is_cli) then cli_output = "\n" end
      output = Hash.new()
      json = JSON.parse(result.body)
      fields = json['fields']

      issue_type = fields['issuetype']['name']
      created_time_s = fields['created']
      status = fields['status']['name']
      summary = fields['summary']
      status_category_changed_time_s = fields['statuscategorychangedate']
      updated_time_s = fields['updated']

      # interesting that priority can be empty!
      if (fields['priority'])
        priority = fields['priority']['name']
      else
        priority = "none"
      end

      labels = ""
      fields['labels'].each { |l|
        labels = labels + l + ","
      }
      labels.delete_suffix!(',')

      components = ""
      fields['components'].each { |c|
        components = components + c['name'] + ","
      }
      components.delete_suffix!(',')

      if (is_cli)
        cli_output = "summary: #{summary}\n" +
                     "type: #{issue_type}\n" +
                     "priority: #{priority}\n" +
                     "status: #{status}\n" +
                     "labels: #{labels}\n" +
                     "components: #{components}\n" +
                     "created: #{created_time_s}\n" +
                     "updated: #{updated_time_s}\n" +
                     "status_category_change: #{status_category_changed_time_s}\n"
      end

      output['summary'] = summary
      output['type'] = issue_type
      output['priority'] = priority
      output['status'] = status
      output['labels'] = labels
      output['components'] = components
      output['created'] = created_time_s
      output['updated'] = updated_time_s
      output['status_category_change'] = status_category_changed_time_s

      sset('get_issue_result', output)
      if (is_cli)
        sset(CLI_OUTPUT, cli_output)
      end
    else
      if (is_cli)
        sset(CLI_OUTPUT, "Unable to retrieve #{key}")
      end
    end

    return result
  end


  #----------------------------------------------------------------------------
  # Retrieve a list of issues which have been updated recently.
  #
  # Note this may not be a full list of unwatched issues if the list is larger
  # than the limit, which defaults to 100. The server may also impose a limit
  # which might be smaller than the requested limit.
  #
  # Required:
  #     username : Authenticate as this user.
  #     password : Password of username.
  #     project  : Project.
  #     hours    : Updated in the last this many hours.
  # Optional:
  #     limit : Return up to this many results (default: 100)
  # Saves to state:
  #     get_recent_result : Array of issue keys
  #
  GetRecent = {
    'description' => "Retrieve list of recently updated issues",
    'required' => {
      'username' => [ '-u', '--user', 'User name' ],
      'password' => [ '-P', '--password', 'Password' ],
      'project' => [ '-c' , '--project', 'Project name (category)' ],
      'hours' => [ '-H', '--hours', 'Updated time window' ],
    },
    'optional' => {
      'limit' => [ '-l', '--limit', 'Limit result set size to this number'],
    }
  }

  def recent
    user = sget('username')
    password = sget('password')
    project = sget('project')
    hours = sget('hours')

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
                       "updated >= -#{hours}h AND project = CER ORDER BY created DESC")
    ssettmp(REQ_PARAMS, params)

    result = yield

    if (result.ok)
      # On success, create a simple key->description hash with the results
      if (is_cli) then cli_output = "\n" end
      recent = Hash.new()
      json = JSON.parse(result.body)

      issues = json['issues']
      if (issues != nil)
        issues.each { |h|
          key = h['key']
          summary = h['fields']['summary']
          recent[key] = summary
          if (is_cli) then cli_output += "#{key} : #{summary}\n" end
        }
      end

      sset('get_recent_result', recent)
      if (is_cli)
        sset(CLI_OUTPUT, cli_output)
      end
    end

    return result
  end


end
