###############################################################################
## File:     Globals.pm
## Synopsys: Contains global variables which store information about
##           reactions, rates, and nodes.
###############################################################################
## Detailed Description:
## ---------------------
##
###############################################################################

#######################################################################################
# Package interface
#######################################################################################
package Globals;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(
	     $quiet
	     $verbose
	     $AVOGADRO
	     $pi
	    );

#######################################################################################
# Modules used
#######################################################################################

#######################################################################################
# Package globals
#######################################################################################
use vars qw($quiet);            # Print all warnings by default
use vars qw($verbose);          # Print extra messages

use vars qw($AVOGADRO);         # Avogadro's number

use vars qw($pi);

#######################################################################################
# Set default values
#######################################################################################
$quiet = 0;
$verbose = 0;

$AVOGADRO = 6.022e23;

# not the same value as Matlab's pi
$pi = "3\.1415926535898" + 0.0;

1;


