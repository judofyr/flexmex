require 'mkmf'
require 'zlib'

$CFLAGS += ' -std=c99'
create_makefile 'flexmex_ext'

