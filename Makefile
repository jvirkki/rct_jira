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

GEM=gem

build:
	$(GEM) build rct_jira.gemspec

install: clean build
	$(GEM) install ./rct_jira-*.gem

publish: clean build
	$(GEM) push ./rct_jira-*.gem

clean:
	rm -f rct_jira-*.gem
