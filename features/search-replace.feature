Feature: Do global search/replace

  Scenario: Basic search/replace
    Given a WP install

    When I run `wp search-replace foo bar`
    Then STDOUT should contain:
      """
      guid
      """

    When I run `wp search-replace foo bar --skip-columns=guid`
    Then STDOUT should not contain:
      """
      guid
      """

    When I run `wp search-replace foo bar --include-columns=post_content`
    Then STDOUT should be a table containing rows:
    | Table    | Column       | Replacements | Type |
    | wp_posts | post_content | 0            | SQL  |


  Scenario: Multisite search/replace
    Given a WP multisite install
    And I run `wp site create --slug="foo" --title="foo" --email="foo@example.com"`
    And I run `wp search-replace foo bar --network`
    Then STDOUT should be a table containing rows:
      | Table      | Column | Replacements | Type |
      | wp_2_posts | guid   | 2            | SQL  |
      | wp_blogs   | path   | 1            | SQL  |

  Scenario: Don't run on unregistered tables by default
    Given a WP install
    And I run `wp db query "CREATE TABLE wp_awesome ( id int(11) unsigned NOT NULL AUTO_INCREMENT, awesome_stuff TEXT, PRIMARY KEY (id) ) ENGINE=InnoDB DEFAULT CHARSET=latin1;"`

    When I run `wp search-replace foo bar`
    Then STDOUT should not contain:
      """
      wp_awesome
      """

    When I run `wp search-replace foo bar --all-tables-with-prefix`
    Then STDOUT should contain:
      """
      wp_awesome
      """

  Scenario: Run on unregistered, unprefixed tables with --all-tables flag
    Given a WP install
    And I run `wp db query "CREATE TABLE awesome_table ( id int(11) unsigned NOT NULL AUTO_INCREMENT, awesome_stuff TEXT, PRIMARY KEY (id) ) ENGINE=InnoDB DEFAULT CHARSET=latin1;"`

    When I run `wp search-replace foo bar`
    Then STDOUT should not contain:
      """
      awesome_table
      """

    When I run `wp search-replace foo bar --all-tables`
    Then STDOUT should contain:
      """
      awesome_table
      """

  Scenario: Run on all tables matching string with wildcard
    Given a WP install

    When I run `wp option set bar foo`
    And I run `wp option get bar`
    Then STDOUT should be:
      """
      foo
      """

    When I run `wp post create --post_title=bar --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `wp post meta add {POST_ID} foo bar`
    Then STDOUT should not be empty

    When I run `wp search-replace bar burrito wp_post\?`
    And STDOUT should be a table containing rows:
      | Table         | Column      | Replacements | Type |
      | wp_posts      | post_title  | 1            | SQL  |
    And STDOUT should not contain:
      """
      wp_options
      """

    When I run `wp post get {POST_ID} --field=title`
    Then STDOUT should be:
      """
      burrito
      """

    When I run `wp post meta get {POST_ID} foo`
    Then STDOUT should be:
      """
      bar
      """

    When I run `wp option get bar`
    Then STDOUT should be:
      """
      foo
      """

    When I try `wp search-replace foo burrito wp_opt\*on`
    Then STDERR should be:
      """
      Error: Couldn't find any tables matching: wp_opt*on
      """

    When I run `wp search-replace foo burrito wp_opt\* wp_postme\*`
    Then STDOUT should be a table containing rows:
      | Table         | Column       | Replacements | Type |
      | wp_options    | option_value | 1            | PHP  |
      | wp_postmeta   | meta_key     | 1            | SQL  |
    And STDOUT should not contain:
      """
      wp_posts
      """

    When I run `wp option get bar`
    Then STDOUT should be:
      """
      burrito
      """

    When I run `wp post meta get {POST_ID} burrito`
    Then STDOUT should be:
      """
      bar
      """

  Scenario: Quiet search/replace
    Given a WP install

    When I run `wp search-replace foo bar --quiet`
    Then STDOUT should be empty

  Scenario: Verbose search/replace
    Given a WP install
    And I run `wp post create --post_title='Replace this text' --porcelain`
    And save STDOUT as {POSTID}

    When I run `wp search-replace 'Replace' 'Replaced' --verbose`
    Then STDOUT should contain:
      """
      Checking: wp_posts.post_title
      1 rows affected
      """

    When I run `wp search-replace 'Replace' 'Replaced' --verbose --precise`
    Then STDOUT should contain:
      """
      Checking: wp_posts.post_title
      1 rows affected
      """

  Scenario: Regex search/replace
    Given a WP install
    When I run `wp search-replace '(Hello)\s(world)' '$2, $1' --regex`
    Then STDOUT should contain:
      """
      wp_posts
      """
    When I run `wp post list --fields=post_title`
    Then STDOUT should contain:
      """
      world, Hello
      """

  Scenario: Regex search/replace with a incorrect `--regex-flags`
    Given a WP install
    When I try `wp search-replace '(Hello)\s(world)' '$2, $1' --regex --regex-flags='kppr'`
    Then STDERR should contain:
      """
      (Hello)\s(world)
      """
    And STDERR should contain:
      """
      kppr
      """
    And the return code should be 1

  Scenario: Search and replace within theme mods
    Given a WP install
    And a setup-theme-mod.php file:
      """
      <?php
      set_theme_mod( 'header_image_data', (object) array( 'url' => 'http://subdomain.example.com/foo.jpg' ) );
      """
    And I run `wp eval-file setup-theme-mod.php`

    When I run `wp theme mod get header_image_data`
    Then STDOUT should be a table containing rows:
      | key               | value                                              |
      | header_image_data | {"url":"http:\/\/subdomain.example.com\/foo.jpg"}  |

    When I run `wp search-replace subdomain.example.com example.com --no-recurse-objects`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | wp_options | option_value | 0            | PHP        |

    When I run `wp search-replace subdomain.example.com example.com`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | wp_options | option_value | 1            | PHP        |

    When I run `wp theme mod get header_image_data`
    Then STDOUT should be a table containing rows:
      | key               | value                                           |
      | header_image_data | {"url":"http:\/\/example.com\/foo.jpg"}  |

  Scenario: Search and replace with quoted strings
    Given a WP install

    When I run `wp post create --post_content='<a href="http://apple.com">Apple</a>' --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `wp post get {POST_ID} --field=content`
    Then STDOUT should be:
      """
      <a href="http://apple.com">Apple</a>
      """

    When I run `wp search-replace '<a href="http://apple.com">Apple</a>' '<a href="http://google.com">Google</a>' --dry-run`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | wp_posts   | post_content | 1            | SQL        |

    When I run `wp search-replace '<a href="http://apple.com">Apple</a>' '<a href="http://google.com">Google</a>'`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | wp_posts   | post_content | 1            | SQL        |

    When I run `wp search-replace '<a href="http://google.com">Google</a>' '<a href="http://apple.com">Apple</a>' --dry-run`
    Then STDOUT should contain:
      """
      1 replacement to be made.
      """

    When I run `wp post get {POST_ID} --field=content`
    Then STDOUT should be:
      """
      <a href="http://google.com">Google</a>
      """

  Scenario: Search and replace with the same terms
    Given a WP install

    When I run `wp search-replace foo foo`
    Then STDERR should be:
      """
      Warning: Replacement value 'foo' is identical to search value 'foo'. Skipping operation.
      """
    And STDOUT should be empty

  Scenario: Search and replace a table that has a multi-column primary key
    Given a WP install
    And I run `wp db query "CREATE TABLE wp_multicol ( "id" bigint(20) NOT NULL AUTO_INCREMENT,"name" varchar(60) NOT NULL,"value" text NOT NULL,PRIMARY KEY ("id","name"),UNIQUE KEY "name" ("name") ) ENGINE=InnoDB DEFAULT CHARSET=utf8 "`
    And I run `wp db query "INSERT INTO wp_multicol VALUES (1, 'foo',  'bar')"`
    And I run `wp db query "INSERT INTO wp_multicol VALUES (2, 'bar',  'foo')"`

    When I run `wp search-replace bar replaced wp_multicol`
    Then STDOUT should be a table containing rows:
      | Table       | Column | Replacements | Type |
      | wp_multicol | name   | 1            | SQL  |
      | wp_multicol | value  | 1            | SQL  |

  Scenario Outline: Large guid search/replace where replacement contains search (or not)
    Given a WP install
    And I run `wp option get siteurl`
    And save STDOUT as {SITEURL}
    And I run `wp post generate --count=20`

    When I run `wp search-replace <flags> {SITEURL} <replacement>`
    Then STDOUT should be a table containing rows:
      | Table    | Column | Replacements | Type |
      | wp_posts | guid   | 22           | SQL  |

    Examples:
      | replacement          | flags     |
      | {SITEURL}/subdir     |           |
      | http://newdomain.com |           |
      | http://newdomain.com | --dry-run |

  Scenario Outline: Choose replacement method (PHP or MySQL/MariaDB) given proper flags or data.
    Given a WP install
    And I run `wp option get siteurl`
    And save STDOUT as {SITEURL}
    When I run `wp search-replace <flags> {SITEURL} http://wordpress.org`

    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | wp_options | option_value | 2            | <serial>   |
      | wp_posts   | post_title   | 0            | <noserial> |

    Examples:
      | flags     | serial | noserial |
      |           | PHP    | SQL      |
      | --precise | PHP    | PHP      |

  Scenario Outline: Ensure search and replace uses PHP (precise) mode when serialized data is found
    Given a WP install
    And I run `wp post create --post_content='<input>' --porcelain`
    And save STDOUT as {CONTROLPOST}
    And I run `wp search-replace --precise foo bar`
    And I run `wp post get {CONTROLPOST} --field=content`
    And save STDOUT as {CONTROL}
    And I run `wp post create --post_content='<input>' --porcelain`
    And save STDOUT as {TESTPOST}
    And I run `wp search-replace foo bar`

    When I run `wp post get {TESTPOST} --field=content`
    Then STDOUT should be:
      """
      {CONTROL}
      """

    Examples:
      | input                                 |
      | a:1:{s:3:"bar";s:3:"foo";}            |
      | O:8:"stdClass":1:{s:1:"a";s:3:"foo";} |

  Scenario: Search replace with a regex flag
    Given a WP install

    When I run `wp search-replace 'EXAMPLE.com' 'BAXAMPLE.com' wp_options --regex`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | wp_options | option_value | 0            | PHP        |

    When I run `wp option get home`
    Then STDOUT should be:
      """
      http://example.com
      """

    When I run `wp search-replace 'EXAMPLE.com' 'BAXAMPLE.com' wp_options --regex --regex-flags=i`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | wp_options | option_value | 5            | PHP        |

    When I run `wp option get home`
    Then STDOUT should be:
      """
      http://BAXAMPLE.com
      """

  Scenario: Search replace with a regex delimiter
    Given a WP install

    When I run `wp search-replace 'HTTP://EXAMPLE.COM' 'http://example.jp/' wp_options --regex --regex-flags=i --regex-delimiter='#'`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | wp_options | option_value | 2            | PHP        |

    When I run `wp option get home`
    Then STDOUT should be:
      """
      http://example.jp
      """

    When I run `wp search-replace 'http://example.jp/' 'http://example.com/' wp_options --regex-delimiter='/'`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | wp_options | option_value | 2            | PHP        |

    When I run `wp option get home`
    Then STDOUT should be:
      """
      http://example.com
      """

    When I try `wp search-replace 'HTTP://EXAMPLE.COM' 'http://example.jp/' wp_options --regex --regex-flags=i --regex-delimiter='1'`
    Then STDERR should be:
      """
      Error: The regex '1HTTP://EXAMPLE.COM1i' fails.
      """
    And the return code should be 1

  Scenario: Formatting as count-only
    Given a WP install
    And I run `wp option set foo 'ALPHA.example.com'`

    # --quite should suppress --format=count
    When I run `wp search-replace 'ALPHA.example.com' 'BETA.example.com' --quiet --format=count`
    Then STDOUT should be empty

    # --format=count should suppress --verbose
    When I run `wp search-replace 'BETA.example.com' 'ALPHA.example.com' --format=count --verbose`
    Then STDOUT should be:
      """
      1
      """

    # The normal command
    When I run `wp search-replace 'ALPHA.example.com' 'BETA.example.com' --format=count`
    Then STDOUT should be:
      """
      1
      """

    # Lets just make sure that zero works, too.
    When I run `wp search-replace 'DELTA.example.com' 'ALPHA.example.com' --format=count`
    Then STDOUT should be:
      """
      0
      """

  Scenario: Search / replace should cater for field/table names that use reserved words or unusual characters
    Given a WP install
    And a esc_sql_ident.sql file:
      """
      CREATE TABLE `TABLE` (`KEY` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT, `VALUES` TEXT, `back``tick` TEXT, `single'double"quote` TEXT, PRIMARY KEY (`KEY`) );
      INSERT INTO `TABLE` (`VALUES`, `back``tick`, `single'double"quote`) VALUES ('v"vvvv_v1', 'v"vvvv_v1', 'v"vvvv_v1' );
      INSERT INTO `TABLE` (`VALUES`, `back``tick`, `single'double"quote`) VALUES ('v"vvvv_v2', 'v"vvvv_v2', 'v"vvvv_v2' );
      """

    When I run `wp db query "SOURCE esc_sql_ident.sql;"`
    Then STDERR should be empty

    When I run `wp search-replace 'v"vvvv_v' 'w"wwww_w' TABLE --format=count`
    Then STDOUT should be:
      """
      6
      """
    And STDERR should be empty

    # Regex uses wpdb::update() which can't handle backticks in field names so avoid `back``tick` column.
    When I run `wp search-replace 'w"wwww_w' 'v"vvvv_v' TABLE --regex --include-columns='VALUES,single'\''double"quote' --format=count`
    Then STDOUT should be:
      """
      4
      """
    And STDERR should be empty

  Scenario: Suppress report or only report changes
    Given a WP install

    When I run `wp option set foo baz`
    And I run `wp option get foo`
    Then STDOUT should be:
      """
      baz
      """

    When I run `wp post create --post_title=baz --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `wp post meta add {POST_ID} foo baz`
    Then STDOUT should not be empty

    When I run `wp search-replace baz baz1`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should be a table containing rows:
    | Table          | Column       | Replacements | Type |
    | wp_commentmeta | meta_key     | 0            | SQL  |
    | wp_options     | option_value | 1            | PHP  |
    | wp_postmeta    | meta_value   | 1            | SQL  |
    | wp_posts       | post_title   | 1            | SQL  |
    | wp_users       | display_name | 0            | SQL  |
    And STDERR should be empty

    When I run `wp search-replace baz1 baz2 --report`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should be a table containing rows:
    | Table          | Column       | Replacements | Type |
    | wp_commentmeta | meta_key     | 0            | SQL  |
    | wp_options     | option_value | 1            | PHP  |
    | wp_postmeta    | meta_value   | 1            | SQL  |
    | wp_posts       | post_title   | 1            | SQL  |
    | wp_users       | display_name | 0            | SQL  |
    And STDERR should be empty

    When I run `wp search-replace baz2 baz3 --no-report`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should not contain:
      """
      Table	Column	Replacements	Type
      """
    And STDOUT should not contain:
      """
      wp_commentmeta	meta_key	0	SQL
      """
    And STDOUT should not contain:
      """
      wp_options	option_value	1	PHP
      """
    And STDERR should be empty

    When I run `wp search-replace baz3 baz4 --no-report-changed-only`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should be a table containing rows:
    | Table          | Column       | Replacements | Type |
    | wp_commentmeta | meta_key     | 0            | SQL  |
    | wp_options     | option_value | 1            | PHP  |
    | wp_postmeta    | meta_value   | 1            | SQL  |
    | wp_posts       | post_title   | 1            | SQL  |
    | wp_users       | display_name | 0            | SQL  |
    And STDERR should be empty

    When I run `wp search-replace baz4 baz5 --report-changed-only`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should end with a table containing rows:
    | Table          | Column       | Replacements | Type |
    | wp_options     | option_value | 1            | PHP  |
    | wp_postmeta    | meta_value   | 1            | SQL  |
    | wp_posts       | post_title   | 1            | SQL  |
    And STDOUT should not contain:
      """
      wp_commentmeta	meta_key	0	SQL
      """
    And STDOUT should not contain:
      """
      wp_users	display_name	0	SQL
      """
    And STDERR should be empty

  Scenario: Deal with non-existent table and table with no primary keys
    Given a WP install

    When I run `wp search-replace foo bar no_such_table`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDOUT should end with a table containing rows:
    | Table         | Column | Replacements | Type |
    | no_such_table |        | skipped      |      |
    And STDERR should be empty

    When I run `wp search-replace foo bar no_such_table --no-report`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDOUT should not contain:
      """
      Table	Column	Replacements	Type
      """
    And STDERR should be:
      """
      Warning: No such table 'no_such_table'.
      """

    When I run `wp db query "CREATE TABLE no_key ( awesome_stuff TEXT );"`
    And I run `wp search-replace foo bar no_key`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDOUT should end with a table containing rows:
    | Table  | Column | Replacements | Type |
    | no_key |        | skipped      |      |
    And STDERR should be empty

    When I run `wp search-replace foo bar no_key --no-report`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDOUT should not contain:
      """
      Table	Column	Replacements	Type
      """
    And STDERR should be:
      """
      Warning: No primary keys for table 'no_key'.
      """

  Scenario: Search / replace is case sensitive
    Given a WP install
    When I run `wp post create --post_title='Case Sensitive' --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `wp search-replace sensitive insensitive`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDERR should be empty

    When I run `wp search-replace sensitive insensitive --dry-run`
    Then STDOUT should contain:
      """
      Success: 0 replacements to be made.
      """
    And STDERR should be empty

    When I run `wp search-replace Sensitive insensitive --dry-run`
    Then STDOUT should contain:
      """
      Success: 1 replacement to be made.
      """
    And STDERR should be empty

    When I run `wp search-replace Sensitive insensitive`
    Then STDOUT should contain:
      """
      Success: Made 1 replacement.
      """
    And STDERR should be empty
