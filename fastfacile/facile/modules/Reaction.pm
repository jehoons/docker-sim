###############################################################################
# File:     Reaction.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Class definition for a biochemical reaction.
###############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

use strict;
use diagnostics;		# equivalent to -w command-line switch
use warnings;

package Reaction;
use Class::Std;
use base qw();
{

    #######################################################################################
    # CLASS ATTRIBUTES
    #######################################################################################

    #######################################################################################
    # ATTRIBUTES
    #######################################################################################

    # self-explanatory
    my %index_of                :ATTR(get => 'index', init_arg => 'index');
    my %substrate_names_ref_of  :ATTR(get => 'substrate_names_ref', init_arg => 'substrate_names_ref');
    my %product_names_ref_of    :ATTR(get => 'product_names_ref', init_arg => 'product_names_ref');
    my %rate_ref_of             :ATTR(get => 'rate_ref', init_arg => 'rate_ref');
    my %velocity_of             :ATTR(set => 'velocity', get => 'velocity');
    my %source_line_of          :ATTR(get => 'source_line', init_arg => 'source_line');
    my %is_rate_law_flag_of     :ATTR(get => 'is_rate_law_flag', init_arg => 'is_rate_law_flag');

    # list of reactions whose substrates are products or substrates of self
    my %dependent_reactions_ref_of :ATTR(get => 'dependent_reactions_ref');

    # for easystoch export, specifies whether dynamic rates are piecewise-continuous or piecewise-linear
    my %easystoch_dynrate_order_of     :ATTR(get => 'easystoch_dynrate_order', set => 'easystoch_dynrate_order', init_arg => 'easystoch_dynrate_order', default => 0);

    #######################################################################################
    # FUNCTIONS
    #######################################################################################

    #######################################################################################
    # CLASS METHODS
    #######################################################################################

    #######################################################################################
    # INSTANCE METHODS
    #######################################################################################
    sub BUILD {
        my ($self, $obj_ID, $arg_ref) = @_;

	# compute velocity term now, since we already have rate
	my $velocity = $arg_ref->{rate_ref}->get_name();  # velocity begins with name...
	my @substrates = @{$arg_ref->{substrate_names_ref}};
	#statement within if used to execute always.
	if ($arg_ref->{is_rate_law_flag} == 0) {
	    # not a rate-law, so equation is interpreted as mass-action, so velocity
	    # is computed as product of rate and substrate concentrations
	    for(my $j = 0; $j < @substrates; $j++){
		$velocity = $velocity . "*" . $substrates[$j];
	    }
	}
	# store velocity in object attribute
	$velocity_of{$obj_ID} = $velocity;

	$dependent_reactions_ref_of{$obj_ID} = [];

	# !!!  have a check on rate dimension here ???
	# should be 0 for rate law, and #substrates else
    }

#    sub DEMOLISH {
#      !!! if ever we wanted to delete a reaction but keep others,
#      !!! we would delete the appropriate element from @reactions
#      !!! using splice, then update the indices of elements following
#    }

    sub get_dependency_list {
	my $self = shift;
	return @{$dependent_reactions_ref_of{ident $self}};
    }
}

# TESTING
sub run_testcases {
    print "Testing class: Reaction\n";

    use Variable;

    print "Creating rx1 object: ";
    my $rate_ref = Variable->new({
	name => "f1",
	index => 0,
	value => 1.0,
	type => "rate",
	dimension => 2,
	is_expression_flag => 0,
	source_line => "f1=1.0",
    });

    my $rx1_ref = Reaction->new({
	index => 0,
	substrate_names_ref => ["X","Y"],
	product_names_ref => ["Z"],
	rate_ref => $rate_ref,
	source_line => "X + Y -> Z",
	is_rate_law_flag => 1,
    });
    print $rx1_ref->_DUMP();

    print "Done testing class: Reaction\n";
}

# Package BEGIN must return true value
return 1;


