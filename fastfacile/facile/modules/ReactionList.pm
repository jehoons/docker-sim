######################################################################################
# File:     ReactionList.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Template for the creation of new object classes.
######################################################################################
# Detailed Description:
# ---------------------
#
#
######################################################################################

use strict;
use diagnostics;		# equivalent to -w command-line switch
use warnings;

package ReactionList;
use Class::Std;
use base qw();
{
    use Carp;
    use Utils;

    use Reaction;

    #######################################################################################
    # CLASS ATTRIBUTES
    #######################################################################################

    #######################################################################################
    # ATTRIBUTES
    #######################################################################################
    my %reactions_of :ATTR(get => 'reactions'); # list of reaction objects ordered and indexed by ID

    #######################################################################################
    # FUNCTIONS
    #######################################################################################

    #######################################################################################
    # CLASS METHODS
    #######################################################################################

    #######################################################################################
    # INSTANCE METHODS
    #######################################################################################
    #--------------------------------------------------------------------------------------
    # Function: BUILD
    # Synopsys: 
    #--------------------------------------------------------------------------------------
    sub BUILD {
	my ($self, $obj_ID, $arg_ref) = @_;

	$reactions_of{$obj_ID} = [];
    }

    sub new_reaction {
	my $self = shift;
	my $arg_ref = shift;
	my $obj_ID = ident $self;

	$arg_ref->{index} = $self->get_count();

	my $reaction_ref = Reaction->new($arg_ref);

	push @{$reactions_of{$obj_ID}}, $reaction_ref;

	return $reaction_ref;
    }

    sub get_list {
	my $self = shift;
	return @{$reactions_of{ident $self}};
    }

    sub get_count {
	my $self = shift;
	return (@{$reactions_of{ident $self}} + 0);
    }

    sub update_dependency_lists {
	my $self = shift;
	my $node_list_ref = shift;
	my $obj_ID = ident $self;

	# build list of nodes affected by reaction, removing duplicates
	# (i.e. if a node is both substrate and product)
	foreach my $reaction_ref (@{$reactions_of{$obj_ID}}) {
	    my %is_dependent_node;
	    foreach my $node_name (@{$reaction_ref->get_substrate_names_ref()}, @{$reaction_ref->get_product_names_ref()}) {
		$is_dependent_node{$node_name} = 1;
	    }
	    # !!! sort the keys ???
	    my @dependent_node_names = keys %is_dependent_node;

	    # build list of reactions affected by reaction, removing duplicates (i.e. if a node is both substrate and product)
	    # !!! (this list should really be built during parsing, not here) ???
	    my %is_dependent_reaction;
	    foreach my $dependent_node_name (@dependent_node_names) {
		my @destroy_reactions = $node_list_ref->lookup_by_name($dependent_node_name)->get_destroy_reactions();
		foreach my $dependent_reaction_ref (@destroy_reactions) {
		    my $index = $dependent_reaction_ref->get_index();
		    $is_dependent_reaction{$index} = 1;
		}
	    }
	    # exclude reaction from its own dependency list
	    # !!! do we assume it is dependent on itself? -> not efficient for null substrate ???
	    # !!! sort the keys ???
	    my $dependent_reactions_ref = $reaction_ref->get_dependent_reactions_ref();
	    @{$dependent_reactions_ref} = grep(($_->get_index() != $reaction_ref->get_index()),
								       map ($reactions_of{$obj_ID}[$_], keys %is_dependent_reaction));
	}
    }

    sub lookup_by_index {
	my $self = shift;
	my $index = shift;

	return $reactions_of{ident $self}[$index];
    }

}


sub run_testcases {
    print "Testing class: ReactionList\n";

    my $rx_list_ref = ReactionList->new({});
    print $rx_list_ref->_DUMP();

    print "Adding reaction: ";
    my $rate1_ref = Variable->new({
	name => "RATE1",
	index => 0,
	value => 1.0,
	type => "rate",
	dimension => 2,
	is_expression_flag => 0,
	source_line => "",
    });
    my $rx1_ref = $rx_list_ref->new_reaction({
	substrate_names_ref => ["X","Y"],
	product_names_ref => ["Z"],
	rate_ref => $rate1_ref,
	source_line => "X + Y -> Z",
	is_rate_law_flag => 1,
    });
    print $rx1_ref->_DUMP();
    print "instance count is ".$rx_list_ref->get_count()."\n";

    print "Adding reaction: ";
    my $rate2_ref = Variable->new({
	name => "RATE2",
	index => 1,
	value => 10.0,
	type => "rate",
	dimension => 2,
	is_expression_flag => 0,
	source_line => "",
    });
    my $rx2_ref = $rx_list_ref->new_reaction({
       substrate_names_ref => ["A","B"],
       product_names_ref => ["C"],
       rate_ref => $rate2_ref,
       source_line => "A + B -> C",
       is_rate_law_flag => 0,
      });
    print $rx2_ref->_DUMP();
    print "instance count is ".$rx_list_ref->get_count()."\n";

    print "Adding reaction: ";
    my $rate3_ref = Variable->new({
	name => "RATE3",
	index => 2,
	value => 5.0,
	type => "rate",
	dimension => 2,
	is_expression_flag => 0,
	source_line => "",
    });
    my $rx3_ref = $rx_list_ref->new_reaction({
       substrate_names_ref => ["A","X"],
       product_names_ref => ["C"],
       rate_ref => $rate3_ref,
       source_line => "A + X -> C",
       is_rate_law_flag => 0,
      });

    print $rx3_ref->_DUMP();
    print "instance count is ".$rx_list_ref->get_count()."\n";

    print "iterating through instance list...\n";
    foreach my $rx_ref ($rx_list_ref->get_list()) {
	print $rx_ref->get_source_line()."\n"; 
    }

    print "Done testing class: ReactionList\n";

}


# Package BEGIN must return true value
return 1;

