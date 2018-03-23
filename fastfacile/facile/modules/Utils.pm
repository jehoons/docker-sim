###############################################################################
## File:     Utils.pm
## Synopsys: Miscellaneous small routines.
###############################################################################
## Detailed Description:
## ---------------------
##
###############################################################################

package Utils;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     is_numeric
	    );

#--------------------------------------------------- #
# Useful routine to check if a string is a number
#--------------------------------------------------- #
sub is_numeric {
    my $value = shift;
    # the following regexp is from Perl Cookbook (R2.1) to determine if string is a number
    if ($value =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) {
	return 1;
    } else {
	return 0;
    }
}

