###############################################################################
# File:     Tables.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Implements lookup table (time,value) functionality.
##############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

package Tables;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

use Globals;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     define_table
	     table
	    );

use POSIX qw(ceil floor);

my %tables = ();
sub define_table {
  my $table_name = shift;
  my @time_value_pairs = @_;

  if (@time_value_pairs % 2 != 0) {
    print "ERROR: table $table_name ends with an incomplete time/value pair\n";
    exit(1);
  }

  # split up time / value pairs
  my @times;
  my @values;
  for (my $i=0; $i < @time_value_pairs; $i+=2) {
      my $j = floor($i / 2);
      $times[$j] = $time_value_pairs[$i];
      $values[$j] = $time_value_pairs[$i+1];
  }

  # store values into table
  $tables{$table_name}{times} = \@times;
  $tables{$table_name}{values} = \@values;
}

sub table {
  my $table_name = shift;
  my $time = shift;
  my $times_ref = $tables{$table_name}{times};
  my $values_ref = $tables{$table_name}{values};

  if ($time eq "time_list") {
      return $times_ref;
  }

  my $value = 0.0;  # default value if first element has time > 0
  # now set $value according to lookup table, which is assumed to be ordered
  for (my $i=0; ($i < @{$times_ref}) && ($time >= $times_ref->[$i]); $i++) {
      $value = $values_ref->[$i];
  }
  return $value;
}


1;  # don't remove -- req'd for module to return true

