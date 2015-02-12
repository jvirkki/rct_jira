#
#  Copyright 2013-2015 Jyri J. Virkki <jyri@virkki.com>
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


# http://guides.rubygems.org/specification-reference/

Gem::Specification.new do |s|

  version = '0.3'

  lib_files = `find lib -type f`

  s.name = 'rct_jira'
  s.version = version
  s.executables << 'jira'
  s.summary = 'rct client support for jira'
  s.description = 'wip'
  s.authors = ["Jyri J. Virkki"]
  s.email = 'jyri@virkki.com'
  s.homepage = 'https://github.com/jvirkki/rct_jira'
  s.files = lib_files.split
  s.rubyforge_project = "nowarning"
  s.license = 'GPLv3'
  s.add_runtime_dependency 'rct', ['>= 0.7', '< 1.0']
end
