.PHONY: test
test:
	codecrafters test

.PHONY :sync_parser
sync_parser:
	rm -rf simplest_sql_parser &&\
	git clone git@github.com:kudojp/simplest_sql_parser.git
	git add ./simplest_sql_parser &&\
	git commit -m "Sync simplest_sql_parser dir with the latest version"
