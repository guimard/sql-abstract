#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Warn;
use Test::Exception;
use Data::Dumper;

use SQL::Abstract::Test import => ['is_same_sql_bind'];

use SQL::Abstract;

#### WARNING ####
#
# -nest has been undocumented on purpose, but is still supported for the
# foreseable future. Do not rip out the -nest tests before speaking to
# someone on the DBIC mailing list or in irc.perl.org#dbix-class
#
#################


my @tests = (
      {
              func   => 'select',
              args   => ['test', '*'],
              stmt   => 'SELECT * FROM test',
              stmt_q => 'SELECT * FROM `test`',
              bind   => []
      },
      {
              func   => 'select',
              args   => ['test', [qw(one two three)]],
              stmt   => 'SELECT one, two, three FROM test',
              stmt_q => 'SELECT `one`, `two`, `three` FROM `test`',
              bind   => []
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => 0 }, [qw/boom bada bing/]],
              stmt   => 'SELECT * FROM test WHERE ( a = ? ) ORDER BY boom, bada, bing',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? ) ORDER BY `boom`, `bada`, `bing`',
              bind   => [0]
      },
      {
              func   => 'select',
              args   => ['test', '*', [ { a => 5 }, { b => 6 } ]],
              stmt   => 'SELECT * FROM test WHERE ( ( a = ? ) OR ( b = ? ) )',
              stmt_q => 'SELECT * FROM `test` WHERE ( ( `a` = ? ) OR ( `b` = ? ) )',
              bind   => [5,6]
      },
      {
              func   => 'select',
              args   => ['test', '*', undef, ['id']],
              stmt   => 'SELECT * FROM test ORDER BY id',
              stmt_q => 'SELECT * FROM `test` ORDER BY `id`',
              bind   => []
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => 'boom' } , ['id']],
              stmt   => 'SELECT * FROM test WHERE ( a = ? ) ORDER BY id',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? ) ORDER BY `id`',
              bind   => ['boom']
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => ['boom', 'bang'] }],
              stmt   => 'SELECT * FROM test WHERE ( ( ( a = ? ) OR ( a = ? ) ) )',
              stmt_q => 'SELECT * FROM `test` WHERE ( ( ( `a` = ? ) OR ( `a` = ? ) ) )',
              bind   => ['boom', 'bang']
      },
      {
              func   => 'select',
              args   => [[qw/test1 test2/], '*', { 'test1.a' => { 'In', ['boom', 'bang'] } }],
              stmt   => 'SELECT * FROM test1, test2 WHERE ( test1.a IN ( ?, ? ) )',
              stmt_q => 'SELECT * FROM `test1`, `test2` WHERE ( `test1`.`a` IN ( ?, ? ) )',
              bind   => ['boom', 'bang']
      },
      {
              func   => 'select',
              args   => [[\'test1', 'test2'], '*', { 'test1.a' => { 'In', ['boom', 'bang'] } }],
              stmt   => 'SELECT * FROM test1, test2 WHERE ( test1.a IN ( ?, ? ) )',
              stmt_q => 'SELECT * FROM test1, `test2` WHERE ( `test1`.`a` IN ( ?, ? ) )',
              bind   => ['boom', 'bang']
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => { 'between', ['boom', 'bang'] } }],
              stmt   => 'SELECT * FROM test WHERE ( a BETWEEN ? AND ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` BETWEEN ? AND ? )',
              bind   => ['boom', 'bang']
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => { '!=', 'boom' } }],
              stmt   => 'SELECT * FROM test WHERE ( a != ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` != ? )',
              bind   => ['boom']
      },
      {
              func   => 'update',
              args   => ['test', {a => 'boom'}, {a => undef}],
              stmt   => 'UPDATE test SET a = ? WHERE ( a IS NULL )',
              stmt_q => 'UPDATE `test` SET `a` = ? WHERE ( `a` IS NULL )',
              bind   => ['boom']
      },
      {
              func   => 'update',
              args   => ['test', {a => 'boom'}, { a => {'!=', "bang" }} ],
              stmt   => 'UPDATE test SET a = ? WHERE ( a != ? )',
              stmt_q => 'UPDATE `test` SET `a` = ? WHERE ( `a` != ? )',
              bind   => ['boom', 'bang']
      },
      {
              func   => 'update',
              args   => ['test', {'a-funny-flavored-candy' => 'yummy', b => 'oops'}, { a42 => "bang" }],
              stmt   => 'UPDATE test SET a-funny-flavored-candy = ?, b = ? WHERE ( a42 = ? )',
              stmt_q => 'UPDATE `test` SET `a-funny-flavored-candy` = ?, `b` = ? WHERE ( `a42` = ? )',
              bind   => ['yummy', 'oops', 'bang']
      },
      {
              func   => 'delete',
              args   => ['test', {requestor => undef}],
              stmt   => 'DELETE FROM test WHERE ( requestor IS NULL )',
              stmt_q => 'DELETE FROM `test` WHERE ( `requestor` IS NULL )',
              bind   => []
      },
      {
              func   => 'delete',
              args   => [[qw/test1 test2 test3/],
                         { 'test1.field' => \'!= test2.field',
                            user => {'!=','nwiger'} },
                        ],
              stmt   => 'DELETE FROM test1, test2, test3 WHERE ( test1.field != test2.field AND user != ? )',
              stmt_q => 'DELETE FROM `test1`, `test2`, `test3` WHERE ( `test1`.`field` != test2.field AND `user` != ? )',  # test2.field is a literal value, cannnot be quoted.
              bind   => ['nwiger']
      },
      {
              func   => 'insert',
              args   => ['test', {a => 1, b => 2, c => 3, d => 4, e => 5}],
              stmt   => 'INSERT INTO test (a, b, c, d, e) VALUES (?, ?, ?, ?, ?)',
              stmt_q => 'INSERT INTO `test` (`a`, `b`, `c`, `d`, `e`) VALUES (?, ?, ?, ?, ?)',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/]],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?)',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?)',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/, undef]],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?, ?)',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?, ?)',
              bind   => [qw/1 2 3 4 5/, undef],
      },
      {
              func   => 'update',
              args   => ['test', {a => 1, b => 2, c => 3, d => 4, e => 5}],
              stmt   => 'UPDATE test SET a = ?, b = ?, c = ?, d = ?, e = ?',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = ?, `c` = ?, `d` = ?, `e` = ?',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'update',
              args   => ['test', {a => 1, b => 2, c => 3, d => 4, e => 5}, {a => {'in', [1..5]}}],
              stmt   => 'UPDATE test SET a = ?, b = ?, c = ?, d = ?, e = ? WHERE ( a IN ( ?, ?, ?, ?, ? ) )',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = ?, `c` = ?, `d` = ?, `e` = ? WHERE ( `a` IN ( ?, ?, ?, ?, ? ) )',
              bind   => [qw/1 2 3 4 5 1 2 3 4 5/],
      },
      {
              func   => 'update',
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", '02/02/02']}, {a => {'between', [1,2]}}],
              stmt   => 'UPDATE test SET a = ?, b = to_date(?, \'MM/DD/YY\') WHERE ( a BETWEEN ? AND ? )',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = to_date(?, \'MM/DD/YY\') WHERE ( `a` BETWEEN ? AND ? )',
              bind   => [qw(1 02/02/02 1 2)],
      },
      {
              func   => 'insert',
              args   => ['test.table', {high_limit => \'max(all_limits)', low_limit => 4} ],
              stmt   => 'INSERT INTO test.table (high_limit, low_limit) VALUES (max(all_limits), ?)',
              stmt_q => 'INSERT INTO `test`.`table` (`high_limit`, `low_limit`) VALUES (max(all_limits), ?)',
              bind   => ['4'],
      },
      {
              func   => 'insert',
              args   => ['test.table', [ \'max(all_limits)', 4 ] ],
              stmt   => 'INSERT INTO test.table VALUES (max(all_limits), ?)',
              stmt_q => 'INSERT INTO `test`.`table` VALUES (max(all_limits), ?)',
              bind   => ['4'],
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns'},
              args   => ['test.table', {one => 2, three => 4, five => 6} ],
              stmt   => 'INSERT INTO test.table (five, one, three) VALUES (?, ?, ?)',
              stmt_q => 'INSERT INTO `test`.`table` (`five`, `one`, `three`) VALUES (?, ?, ?)',
              bind   => [['five', 6], ['one', 2], ['three', 4]],  # alpha order, man...
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns', case => 'lower'},
              args   => ['test.table', [qw/one two three/], {one => 2, three => 4, five => 6} ],
              stmt   => 'select one, two, three from test.table where ( five = ? and one = ? and three = ? )',
              stmt_q => 'select `one`, `two`, `three` from `test`.`table` where ( `five` = ? and `one` = ? and `three` = ? )',
              bind   => [['five', 6], ['one', 2], ['three', 4]],  # alpha order, man...
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns', cmp => 'like'},
              args   => ['testin.table2', {One => 22, Three => 44, FIVE => 66},
                                          {Beer => 'is', Yummy => '%YES%', IT => ['IS','REALLY','GOOD']}],
              stmt   => 'UPDATE testin.table2 SET FIVE = ?, One = ?, Three = ? WHERE '
                       . '( Beer LIKE ? AND ( ( IT LIKE ? ) OR ( IT LIKE ? ) OR ( IT LIKE ? ) ) AND Yummy LIKE ? )',
              stmt_q => 'UPDATE `testin`.`table2` SET `FIVE` = ?, `One` = ?, `Three` = ? WHERE '
                       . '( `Beer` LIKE ? AND ( ( `IT` LIKE ? ) OR ( `IT` LIKE ? ) OR ( `IT` LIKE ? ) ) AND `Yummy` LIKE ? )',
              bind   => [['FIVE', 66], ['One', 22], ['Three', 44], ['Beer','is'],
                         ['IT','IS'], ['IT','REALLY'], ['IT','GOOD'], ['Yummy','%YES%']],
      },
      {
              func   => 'select',
              args   => ['test', '*', {priority => [ -and => {'!=', 2}, { -not_like => '3%'} ]}],
              stmt   => 'SELECT * FROM test WHERE ( ( ( priority != ? ) AND ( priority NOT LIKE ? ) ) )',
              stmt_q => 'SELECT * FROM `test` WHERE ( ( ( `priority` != ? ) AND ( `priority` NOT LIKE ? ) ) )',
              bind   => [qw(2 3%)],
      },
      {
              func   => 'select',
              args   => ['Yo Momma', '*', { user => 'nwiger',
                                       -nest => [ workhrs => {'>', 20}, geo => 'ASIA' ] }],
              stmt   => 'SELECT * FROM Yo Momma WHERE ( ( ( workhrs > ? ) OR ( geo = ? ) ) AND user = ? )',
              stmt_q => 'SELECT * FROM `Yo Momma` WHERE ( ( ( `workhrs` > ? ) OR ( `geo` = ? ) ) AND `user` = ? )',
              bind   => [qw(20 ASIA nwiger)],
      },
      {
              func   => 'update',
              args   => ['taco_punches', { one => 2, three => 4 },
                                         { bland => [ -and => {'!=', 'yes'}, {'!=', 'YES'} ],
                                           tasty => { '!=', [qw(yes YES)] },
                                           -nest => [ face => [ -or => {'=', 'mr.happy'}, {'=', undef} ] ] },
                        ],
              stmt   => 'UPDATE taco_punches SET one = ?, three = ? WHERE ( ( ( ( ( face = ? ) OR ( face IS NULL ) ) ) )'
                      . ' AND ( ( bland != ? ) AND ( bland != ? ) ) AND ( ( tasty != ? ) OR ( tasty != ? ) ) )',
              stmt_q => 'UPDATE `taco_punches` SET `one` = ?, `three` = ? WHERE ( ( ( ( ( `face` = ? ) OR ( `face` IS NULL ) ) ) )'
                      . ' AND ( ( `bland` != ? ) AND ( `bland` != ? ) ) AND ( ( `tasty` != ? ) OR ( `tasty` != ? ) ) )',
              bind   => [qw(2 4 mr.happy yes YES yes YES)],
      },
      {
              func   => 'select',
              args   => ['jeff', '*', { name => {'ilike', '%smith%', -not_in => ['Nate','Jim','Bob','Sally']},
                                       -nest => [ -or => [ -and => [age => { -between => [20,30] }, age => {'!=', 25} ],
                                                                   yob => {'<', 1976} ] ] } ],
              stmt   => 'SELECT * FROM jeff WHERE ( ( ( ( ( ( ( age BETWEEN ? AND ? ) AND ( age != ? ) ) ) OR ( yob < ? ) ) ) )'
                      . ' AND name NOT IN ( ?, ?, ?, ? ) AND name ILIKE ? )',
              stmt_q => 'SELECT * FROM `jeff` WHERE ( ( ( ( ( ( ( `age` BETWEEN ? AND ? ) AND ( `age` != ? ) ) ) OR ( `yob` < ? ) ) ) )'
                      . ' AND `name` NOT IN ( ?, ?, ?, ? ) AND `name` ILIKE ? )',
              bind   => [qw(20 30 25 1976 Nate Jim Bob Sally %smith%)]
      },
      {
              func   => 'update',
# LDNOTE : removed the "-maybe", because we no longer admit unknown ops
#
# acked by RIBASUSHI
#              args   => ['fhole', {fpoles => 4}, [-maybe => {race => [-and => [qw(black white asian)]]},
              args   => ['fhole', {fpoles => 4}, [
                          { race => [qw/-or black white asian /] },
                          { -nest => { firsttime => [-or => {'=','yes'}, undef] } },
                          { -and => [ { firstname => {-not_like => 'candace'} }, { lastname => {-in => [qw(jugs canyon towers)] } } ] },
                        ] ],
              stmt   => 'UPDATE fhole SET fpoles = ? WHERE ( ( ( ( ( ( ( race = ? ) OR ( race = ? ) OR ( race = ? ) ) ) ) ) )'
                      . ' OR ( ( ( ( firsttime = ? ) OR ( firsttime IS NULL ) ) ) ) OR ( ( ( firstname NOT LIKE ? ) ) AND ( lastname IN (?, ?, ?) ) ) )',
              stmt_q => 'UPDATE `fhole` SET `fpoles` = ? WHERE ( ( ( ( ( ( ( `race` = ? ) OR ( `race` = ? ) OR ( `race` = ? ) ) ) ) ) )'
                      . ' OR ( ( ( ( `firsttime` = ? ) OR ( `firsttime` IS NULL ) ) ) ) OR ( ( ( `firstname` NOT LIKE ? ) ) AND ( `lastname` IN( ?, ?, ? )) ) )',
              bind   => [qw(4 black white asian yes candace jugs canyon towers)]
      },
      {
              func   => 'insert',
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", '02/02/02']}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              bind   => [qw(1 02/02/02)],
      },
      {
              func   => 'select',
# LDNOTE: modified test below because we agreed with MST that literal SQL
#         should not automatically insert a '='; the user has to do it
#
# acked by MSTROUT
#              args   => ['test', '*', { a => \["to_date(?, 'MM/DD/YY')", '02/02/02']}],
              args   => ['test', '*', { a => \["= to_date(?, 'MM/DD/YY')", '02/02/02']}],
              stmt   => q{SELECT * FROM test WHERE ( a = to_date(?, 'MM/DD/YY') )},
              stmt_q => q{SELECT * FROM `test` WHERE ( `a` = to_date(?, 'MM/DD/YY') )},
              bind   => ['02/02/02'],
      },
      {
              func   => 'insert',
              new    => {array_datatypes => 1},
              args   => ['test', {a => 1, b => [1, 1, 2, 3, 5, 8]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, ?)',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, ?)',
              bind   => [1, [1, 1, 2, 3, 5, 8]],
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns', array_datatypes => 1},
              args   => ['test', {a => 1, b => [1, 1, 2, 3, 5, 8]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, ?)',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, ?)',
              bind   => [[a => 1], [b => [1, 1, 2, 3, 5, 8]]],
      },
      {
              func   => 'update',
              new    => {array_datatypes => 1},
              args   => ['test', {a => 1, b => [1, 1, 2, 3, 5, 8]}],
              stmt   => 'UPDATE test SET a = ?, b = ?',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = ?',
              bind   => [1, [1, 1, 2, 3, 5, 8]],
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns', array_datatypes => 1},
              args   => ['test', {a => 1, b => [1, 1, 2, 3, 5, 8]}],
              stmt   => 'UPDATE test SET a = ?, b = ?',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = ?',
              bind   => [[a => 1], [b => [1, 1, 2, 3, 5, 8]]],
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => {'>', \'1 + 1'}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a > 1 + 1 AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` > 1 + 1 AND `b` = ? )',
              bind   => [8],
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => {'<' => \["to_date(?, 'MM/DD/YY')", '02/02/02']}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a < to_date(?, \'MM/DD/YY\') AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` < to_date(?, \'MM/DD/YY\') AND `b` = ? )',
              bind   => ['02/02/02', 8],
      },
      {
              func   => 'insert',
              args   => ['test', {a => 1, b => 2, c => 3, d => 4, e => { -answer => 42 }}],
              stmt   => 'INSERT INTO test (a, b, c, d, e) VALUES (?, ?, ?, ?, ANSWER(?))',
              stmt_q => 'INSERT INTO `test` (`a`, `b`, `c`, `d`, `e`) VALUES (?, ?, ?, ?, ANSWER(?))',
              bind   => [qw/1 2 3 4 42/],
      },
      {
              func   => 'update',
              args   => ['test', {a => 1, b => \["42"]}, {a => {'between', [1,2]}}],
              stmt   => 'UPDATE test SET a = ?, b = 42 WHERE ( a BETWEEN ? AND ? )',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = 42 WHERE ( `a` BETWEEN ? AND ? )',
              bind   => [qw(1 1 2)],
      },
      {
              func   => 'insert',
              args   => ['test', {a => 1, b => \["42"]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, 42)',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, 42)',
              bind   => [qw(1)],
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => \["= 42"], b => 1}],
              stmt   => q{SELECT * FROM test WHERE ( a = 42 ) AND (b = ? )},
              stmt_q => q{SELECT * FROM `test` WHERE ( `a` = 42 ) AND ( `b` = ? )},
              bind   => [qw(1)],
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => {'<' => \["42"]}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a < 42 AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` < 42 AND `b` = ? )',
              bind   => [qw(8)],
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", [dummy => '02/02/02']]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              bind   => [[a => '1'], [dummy => '02/02/02']],
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", [dummy => '02/02/02']]}, {a => {'between', [1,2]}}],
              stmt   => 'UPDATE test SET a = ?, b = to_date(?, \'MM/DD/YY\') WHERE ( a BETWEEN ? AND ? )',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = to_date(?, \'MM/DD/YY\') WHERE ( `a` BETWEEN ? AND ? )',
              bind   => [[a => '1'], [dummy => '02/02/02'], [a => '1'], [a => '2']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => \["= to_date(?, 'MM/DD/YY')", [dummy => '02/02/02']]}],
              stmt   => q{SELECT * FROM test WHERE ( a = to_date(?, 'MM/DD/YY') )},
              stmt_q => q{SELECT * FROM `test` WHERE ( `a` = to_date(?, 'MM/DD/YY') )},
              bind   => [[dummy => '02/02/02']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {'<' => \["to_date(?, 'MM/DD/YY')", [dummy => '02/02/02']]}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a < to_date(?, \'MM/DD/YY\') AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` < to_date(?, \'MM/DD/YY\') AND `b` = ? )',
              bind   => [[dummy => '02/02/02'], [b => 8]],
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", '02/02/02']}],
              exception_like => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", '02/02/02']}, {a => {'between', [1,2]}}],
              exception_like => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => \["= to_date(?, 'MM/DD/YY')", '02/02/02']}],
              exception_like => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {'<' => \["to_date(?, 'MM/DD/YY')", '02/02/02']}, b => 8 }],
              exception_like => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {-in => \["(SELECT d FROM to_date(?, 'MM/DD/YY') AS d)", [dummy => '02/02/02']]}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a IN (SELECT d FROM to_date(?, \'MM/DD/YY\') AS d) AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IN (SELECT d FROM to_date(?, \'MM/DD/YY\') AS d) AND `b` = ? )',
              bind   => [[dummy => '02/02/02'], [b => 8]],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {-in => \["(SELECT d FROM to_date(?, 'MM/DD/YY') AS d)", '02/02/02']}, b => 8 }],
              exception_like => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", [{dummy => 1} => '02/02/02']]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              bind   => [[a => '1'], [{dummy => 1} => '02/02/02']],
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", [{dummy => 1} => '02/02/02']], c => { -lower => 'foo' }}, {a => {'between', [1,2]}}],
              stmt   => "UPDATE test SET a = ?, b = to_date(?, 'MM/DD/YY'), c = LOWER(?) WHERE ( a BETWEEN ? AND ? )",
              stmt_q => "UPDATE `test` SET `a` = ?, `b` = to_date(?, 'MM/DD/YY'), `c` = LOWER(?) WHERE ( `a` BETWEEN ? AND ? )",
              bind   => [[a => '1'], [{dummy => 1} => '02/02/02'], [c => 'foo'], [a => '1'], [a => '2']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => \["= to_date(?, 'MM/DD/YY')", [{dummy => 1} => '02/02/02']]}],
              stmt   => q{SELECT * FROM test WHERE ( a = to_date(?, 'MM/DD/YY') )},
              stmt_q => q{SELECT * FROM `test` WHERE ( `a` = to_date(?, 'MM/DD/YY') )},
              bind   => [[{dummy => 1} => '02/02/02']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {'<' => \["to_date(?, 'MM/DD/YY')", [{dummy => 1} => '02/02/02']]}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a < to_date(?, \'MM/DD/YY\') AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` < to_date(?, \'MM/DD/YY\') AND `b` = ? )',
              bind   => [[{dummy => 1} => '02/02/02'], [b => 8]],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { -or => [ -and => [ a => 'a', b => 'b' ], -and => [ c => 'c', d => 'd' ]  ]  }],
              stmt   => 'SELECT * FROM test WHERE ( a = ? AND b = ? ) OR ( c = ? AND d = ?  )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? AND `b` = ?  ) OR ( `c` = ? AND `d` = ? )',
              bind   => [[a => 'a'], [b => 'b'], [ c => 'c'],[ d => 'd']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', [ { a => 1, b => 1}, [ a => 2, b => 2] ] ],
              stmt   => 'SELECT * FROM test WHERE ( a = ? AND b = ? ) OR ( a = ? OR b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? AND `b` = ? ) OR ( `a` = ? OR `b` = ? )',
              bind   => [[a => 1], [b => 1], [ a => 2], [ b => 2]],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', [ [ a => 1, b => 1], { a => 2, b => 2 } ] ],
              stmt   => 'SELECT * FROM test WHERE ( a = ? OR b = ? ) OR ( a = ? AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? OR `b` = ? ) OR ( `a` = ? AND `b` = ? )',
              bind   => [[a => 1], [b => 1], [ a => 2], [ b => 2]],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => 'id' }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING `id`',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => 'id, foo, bar' }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id, foo, bar',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING `id, foo, bar`',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => [qw(id  foo  bar) ] }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id, foo, bar',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING `id`, `foo`, `bar`',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => \'id, foo, bar' }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id, foo, bar',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING id, foo, bar',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => \'id' }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING id',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', [ Y => { '=' => { -max => { -LENGTH => { -min => 'x' } } } } ] ],
              stmt   => 'SELECT * FROM test WHERE ( Y = ( MAX( LENGTH( MIN ? ) ) ) )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `Y` = ( MAX( LENGTH( MIN ? ) ) ) )',
              bind   => [[Y => 'x']],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { -in => [] }, b => { -not_in => [] }, c => { -in => 42 } }],
              stmt => 'SELECT * FROM test WHERE ( 0=1 AND 1=1 AND c IN ( ? ))',
              stmt_q => 'SELECT * FROM `test` WHERE ( 0=1 AND 1=1 AND `c` IN ( ? ))',
              bind => [ 42 ],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { -in => [] }, b => { -not_in => [] } }],
              stmt => 'SELECT * FROM test WHERE ( 0=1 AND 1=1 )',
              stmt_q => 'SELECT * FROM `test` WHERE ( 0=1 AND 1=1 )',
              bind => [],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { -in => [42, undef] }, b => { -not_in => [42, undef] } } ],
              stmt => 'SELECT * FROM test WHERE ( ( a IN ( ? ) OR a IS NULL ) AND b NOT IN ( ? ) AND b IS NOT NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( ( `a` IN ( ? ) OR `a` IS NULL ) AND `b` NOT IN ( ? ) AND `b` IS NOT NULL )',
              bind => [ 42, 42 ],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { -in => [undef] }, b => { -not_in => [undef] } } ],
              stmt => 'SELECT * FROM test WHERE ( a IS NULL AND b IS NOT NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IS NULL AND `b` IS NOT NULL )',
              bind => [],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { '=' => undef }, b => { -is => undef }, c => { -like => undef } }],
              stmt => 'SELECT * FROM test WHERE ( a IS NULL AND b IS NULL AND c IS NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IS NULL AND `b` IS NULL AND `c` IS NULL )',
              bind => [],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { '!=' => undef }, b => { -is_not => undef }, c => { -not_like => undef } }],
              stmt => 'SELECT * FROM test WHERE ( a IS NOT NULL AND b IS NOT  NULL AND c IS NOT  NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IS NOT  NULL AND `b` IS NOT  NULL AND `c` IS NOT  NULL )',
              bind => [],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { IS => undef }, b => { LIKE => undef } }],
              stmt => 'SELECT * FROM test WHERE ( a IS NULL AND b IS NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IS NULL AND `b` IS NULL )',
              bind => [],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { 'IS NOT' => undef }, b => { 'NOT LIKE' => undef } }],
              stmt => 'SELECT * FROM test WHERE ( a IS NOT NULL AND b IS NOT  NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IS NOT  NULL AND `b` IS NOT  NULL )',
              bind => [],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { -in => undef } }],
              exception_like => qr/Argument passed to the 'IN' operator can not be undefined/,
      },
);

# check is( not) => undef
for my $op ( qw(not is is_not), 'is not' ) {
  (my $sop = uc $op) =~ s/_/ /gi;

  $sop = 'IS NOT' if $sop eq 'NOT';

  for my $uc (0, 1) {
    for my $prefix ('', '-') {
      push @tests, {
        func => 'where',
        args => [{ a => { ($prefix . ($uc ? uc $op : lc $op) ) => undef } }],
        stmt => "WHERE a $sop NULL",
        stmt_q => "WHERE `a` $sop NULL",
        bind => [],
      };
    }
  }
}

for my $t (@tests) {
  local $"=', ';

  my $new = $t->{new} || {};
  $new->{debug} = $ENV{DEBUG} || 0;

  for my $quoted (0, 1) {

    my $maker = SQL::Abstract->new(%$new, $quoted
      ? (quote_char => '`', name_sep => '.')
      : ()
    );

    my($stmt, @bind);

    my $cref = sub {
      my $op = $t->{func};
      ($stmt, @bind) = $maker->$op (@ { $t->{args} } );
    };

    if ($t->{exception_like}) {
      throws_ok(
        sub { $cref->() },
        $t->{exception_like},
        "throws the expected exception ($t->{exception_like})"
      );
    } else {
      if ($t->{warning_like}) {
        warning_like(
          sub { $cref->() },
          $t->{warning_like},
          "issues the expected warning ($t->{warning_like})"
        );
      }
      else {
        unless (eval { $cref->(); 1 }) {
          die "Unexpected exception thrown for structure:\n"
              .Dumper($t)."Exception was: $@";
        }
      }

      is_same_sql_bind(
        $stmt,
        \@bind,
        $quoted ? $t->{stmt_q}: $t->{stmt},
        $t->{bind}
      );
    }
  }
}

done_testing;
