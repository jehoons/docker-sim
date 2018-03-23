######################################################################################
# File:     NodeList.pm
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

package NodeList;
use Class::Std;
use base qw();
{
    use Carp;
    use Utils;

    use Node;

    #######################################################################################
    # CLASS ATTRIBUTES
    #######################################################################################

    #######################################################################################
    # ATTRIBUTES
    #######################################################################################
    my %nodes_of :ATTR(get => 'nodes');
    my %free_index_of :ATTR(get => 'free_index', set => 'free_index', init_arg => 0);
    my %nonfree_index_of :ATTR(get => 'nonfree_index', set => 'nonfree_index', init_arg => 0);
    my %constrained_index_of :ATTR(get => 'constrained_index', set => 'constrained_index', init_arg => 0);

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

	$nodes_of{$obj_ID} = [];
    }

    sub new_node {
	my $self = shift;
	my $arg_ref = shift;
	my $obj_ID = ident $self;

	my $node_name = $arg_ref->{name};

	# check that no node already exists with the same name
	if (defined $self->lookup_by_name($node_name)) {
	    print "ERROR: can't create species $node_name because there already exists a species with the same name\n";
	    exit(1);
	}

	$arg_ref->{index} = $self->get_count();

	my $node_ref = Node->new($arg_ref);

	push @{$nodes_of{$obj_ID}}, $node_ref;
	
	return $node_ref;
    }

    sub get_list {
	my $self = shift;
	my $obj_ID = ident $self;

	return @{$nodes_of{$obj_ID}};
    }

    sub get_count {
	my $self = shift;
	my $obj_ID = ident $self;

	return (@{$nodes_of{$obj_ID}} + 0);
    }

    sub get_names {
	my $self =shift;
	my $obj_ID = ident $self;

	my @names = map($_->get_name(),@{$nodes_of{$obj_ID}});
	return @names;
    }

    # returns index and object handle
    sub lookup_by_name {
	my $self = shift;
	my $obj_ID = ident $self;

	my $name = shift;
	for (my $i=0; $i < @{$nodes_of{$obj_ID}}; $i++) {
	    if ($nodes_of{$obj_ID}[$i]->get_name() eq $name) {
		return $nodes_of{$obj_ID}[$i];
	    }
	}
	return undef;
    }

    # returns list of all promoter nodes
    sub get_promoters {
	my $self = shift;
	my $obj_ID = ident $self;

	return grep($_->is_promoter(), @{$nodes_of{$obj_ID}})
    }

    sub designate_as_free {
	my $self = shift; my $obj_ID = ident $self;
	my $node_name = shift;
	
	my $node_ref = $self->lookup_by_name($node_name);

	if (defined $node_ref) {
	    $node_ref->designate_as_free($free_index_of{$obj_ID}++);
	}
	return $node_ref;
    }

    sub designate_as_nonfree {
	my $self = shift; my $obj_ID = ident $self;
	my $node_name = shift;
	
	my $node_ref = $self->lookup_by_name($node_name);

	if (defined $node_ref) {
	    $node_ref->designate_as_nonfree($nonfree_index_of{$obj_ID}++);
	}
	return $node_ref;
    }

    sub designate_as_constrained {
	my $self = shift; my $obj_ID = ident $self;
	my $node_name = shift;
	
	my $node_ref = $self->lookup_by_name($node_name);

	if (defined $node_ref) {
	    $node_ref->designate_as_constrained($constrained_index_of{$obj_ID}++);
	}
	return $node_ref;
    }

    # get list of free nodes with those specified in equation file first and ordered identically
    sub get_ordered_free_node_list {
	my $self = shift;
	my $obj_ID = ident $self;

	my @nodes = @{$nodes_of{$obj_ID}};

	# get all nodes that remain free after moiety analysis
	my @free_nodes = grep ($_->get_is_constrained_flag() != 1, @nodes);

	# from those nodes, extract the ones that the user specified should be free and
	# sort them according the order given by equation file
	my @user_specified_free_nodes = sort {$a->get_free_index() <=> $b->get_free_index()} (grep ($_->get_is_free_flag() == 1, @free_nodes));
	# get the free nodes that the user did not explicitly specify as free but were so after analysis
	my @other_free_nodes = grep ($_->get_is_free_flag() == 0, @free_nodes);

	# concatenate the two lists and return
	my @ordered_free_nodes = (@user_specified_free_nodes, @other_free_nodes);
	return @ordered_free_nodes;
    }

    
}


sub run_testcases {
    print "Testing class: NodeList\n";

    my $node_list_ref = NodeList->new({});

    print "Creating node1 object: ";
    my $node1_ref = $node_list_ref->new_node({
	name => "A",
	index => 0,
      });
    print $node1_ref->_DUMP();
    print "node count is ".$node_list_ref->get_count()."\n";

    print "Creating node2 object: ";
    my $node2_ref = $node_list_ref->new_node({
	name => "B",
	index => 1,
      });

    print $node2_ref->_DUMP();
    print "node count is ".$node_list_ref->get_count()."\n";

    print "Creating node3 object: ";
    my $node3_ref = $node_list_ref->new_node({
	name => "C",
	index => 2,
      });

    print $node3_ref->_DUMP();
    print "node count is ".$node_list_ref->get_count()."\n";

    print "iterating through node list...\n";
    foreach my $node_ref ($node_list_ref->get_list()) {
	print "node ".$node_ref->get_name()."\n"; 
    }


    print "Done testing class: NodeList\n";
}


# Package BEGIN must return true value
return 1;

