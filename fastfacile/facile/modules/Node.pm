###############################################################################
# File:     Node.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Class definition for a biochemical node (species).  A list
#           of objects created is maintained as a package global.
###############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

use strict;
use diagnostics;		# equivalent to -w command-line switch
use warnings;

package Node;
use Class::Std;
use base qw();
{
    use Carp;

    use Globals;

    #######################################################################################
    # ATTRIBUTES
    #######################################################################################

    my %index_of                     :ATTR(get => 'index', init_arg => 'index');
    my %name_of                      :ATTR(get => 'name', init_arg => 'name');
    my %initial_value_of             :ATTR(get => 'initial_value', default => 0.0);
    my %initial_value_set_flag_of    :ATTR(get => 'initial_value_set_flag', default => 0);
    my %initial_value_units_of       :ATTR(get => 'initial_value_units', set => 'initial_value_units');
    my %constraint_expression        :ATTR(get => 'constraint_expression', set => 'constraint_expression');
    my %destroy_reactions_ref_of     :ATTR(get => 'destroy_reactions_ref');
    my %create_reactions_ref_of      :ATTR(get => 'create_reactions_ref');

    # attribute determines if user wants this node to be plotted
    # (support depends on target output)
    my %probe_flag_of                 :ATTR(get => 'probe_flag', set => 'probe_flag', init_arg => 'probe_flag', default => 0);

    # ID number field used when ordering different from that specified by the index
    # (used for EasyStoch simulator input file)
    my %ID_of                        :ATTR(get => 'ID', set => 'ID', default => -1);

    # Attributes used by EasyStoch.pm
    # for promoters
    my %replication_time_of          :ATTR(get => 'replication_time');
    my %associated_complexes_ref_of  :ATTR;
    # for protein-DNA complexes
    my %associated_promoter_of       :ATTR(get => 'associated_promoter', set => 'associated_promoter');

    # attributes to track whether variable is designated as free/constrained by user for moiety analysis
    # -- free/nonfree: these attributes track what the user wanted as specified in the input file
    # -- constrained: this is what the moiety analysis determines are the constrained variables,
    #    which normally is the same set as the ones designated as nonfree by the user
    my %free_index_of                 :ATTR(get => 'free_index');
    my %nonfree_index_of              :ATTR(get => 'nonfree_index');
    my %constrained_index_of          :ATTR(get => 'constrained_index');
    my %nonfree_expression_ref_of     :ATTR(get => 'nonfree_expression_ref', set => 'nonfree_expression_ref');

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

	# can't use 'default' of ATTR to initialize to other than a literal
	$destroy_reactions_ref_of{ident $self} = [];
	$create_reactions_ref_of{ident $self} = [];

    }

#    sub DEMOLISH {
#      !!! if ever we wanted to delete a node but keep others,
#      !!! we would delete the appropriate element from @nodes
#      !!! using splice, then update the indices of elements following
#    }

    sub set_initial_value {
	my $self = shift;
	my $initial_value = shift;

	my $name = $name_of{ident $self};
	if ($initial_value_set_flag_of{ident $self} != 0) {
	    print "Warning: initial value of $name has already been set\n" if (!$quiet);
	    if ($initial_value != $initial_value_of{ident $self}) {
		print "ERROR: initial value of $name has already been set to a different value (previously ".$initial_value_of{ident $self}.")\n";
		exit(1);
	    }
	}
	$initial_value_of{ident $self} = $initial_value;
	$initial_value_set_flag_of{ident $self} = 1;
    }

    sub set_replication_time {
	my $self = shift;
	my $replication_time = shift;

	my $name = $name_of{ident $self};
	if (exists $replication_time_of{ident $self}) {
	    print "ERROR:  Already defined a replication time for promoter $name\n";
	    exit(1);
	} else {
	    $replication_time_of{ident $self} = $replication_time;
	}
    }

    sub is_promoter {
	my $self = shift;
	return (defined $replication_time_of{ident $self}) ? 1 : 0;
    }

    sub is_complex {
	my $self = shift;
	return (defined $associated_promoter_of{ident $self}) ? 1 : 0;
    }

    sub add_associated_complex {
	my $self = shift;
	my $associated_complex_ref = shift;
	push @{$associated_complexes_ref_of{ident $self}}, $associated_complex_ref;

    }

    sub get_associated_complexes {
	my $self = shift;
	return @{$associated_complexes_ref_of{ident $self}};
    }

    sub add_destroy_reaction {
	my $self = shift;
	my $reaction_ref = shift;
	push @{$destroy_reactions_ref_of{ident $self}}, $reaction_ref;
    }

    sub add_create_reaction {
	my $self = shift;
	my $reaction_ref = shift;
	push @{$create_reactions_ref_of{ident $self}}, $reaction_ref;
    }

    sub get_destroy_reactions {
	my $self = shift;
	return @{$destroy_reactions_ref_of{ident $self}};
    }

    sub get_create_reactions {
	my $self = shift;
	return @{$create_reactions_ref_of{ident $self}};
    }

    sub designate_as_free {
	my $self = shift;
	my $free_index = shift;

	if ($self->get_is_nonfree_flag()) {
	    my $name = $self->get_name();
	    print "ERROR: cannot designate node $name as independent because it has already been designated as a dependent node\n";
	    exit(1);
	} else {
	    $free_index_of{ident $self} = $free_index;
	}
    }

    sub designate_as_nonfree {
	my $self = shift;
	my $nonfree_index = shift;

	if ($self->get_is_free_flag()) {
	    my $name = $self->get_name();
	    print "ERROR: cannot designate node $name as dependent because it has already been designated as an independent node\n";
	    exit(1);
	} else {
	    $nonfree_index_of{ident $self} = $nonfree_index;
	}
    }

    sub designate_as_constrained {
	my $self = shift;
	my $constrained_index = shift;

	$constrained_index_of{ident $self} = $constrained_index;
    }

    sub get_is_free_flag {
	my $self = shift;
	return (defined $free_index_of{ident $self}) ? 1 : 0;
    }

    sub get_is_nonfree_flag {
	my $self = shift;
	return (defined $nonfree_index_of{ident $self}) ? 1 : 0;
    }

    sub get_is_constrained_flag {
	my $self = shift;
	return (defined $constrained_index_of{ident $self}) ? 1 : 0;
    }

    sub get_initial_value_in_molecules {
	my $self = shift;
	my $compartment_volume = shift;

	# don't care about units if initial value is zero
	if ($initial_value_of{ident $self} == 0) {
	    my $num_molecules = $initial_value_of{ident $self};
	    return $num_molecules;
	}

	if ($self->get_initial_value_units() =~ /^u?M$/ &&
	    $compartment_volume eq "NOT_SPECIFIED") {
	    print "ERROR: need to specify compartment volume to convert initial conditions to no. molecules\n";
	    exit(1);
	}

	if ($self->get_initial_value_units() eq "molecules") {
	    my $num_molecules = $initial_value_of{ident $self};
	    return $num_molecules;
	}
	if ($self->get_initial_value_units() eq "uM") {
	    my $num_molecules = $initial_value_of{ident $self} * 1.0e-6 * $compartment_volume * $AVOGADRO;
	    return int (sprintf("%.0f", $num_molecules));
	}
	if ($self->get_initial_value_units() eq "M") {
	    my $num_molecules = $initial_value_of{ident $self} * $compartment_volume * $AVOGADRO;
	    return int (sprintf("%.0f", $num_molecules));
	}
	
	print "ERROR: internal error in get_initial_value_in_molecules(), exiting....\n";
	exit(1);
    }

    sub get_initial_value_in_molarity {
	my $self = shift;
	my $compartment_volume = shift;

	if (!defined $compartment_volume) {
	    print "ERROR: internal error -- argument not defined\n";
	    exit(1);
	}

	# don't care about units if initial value is zero
	if ($initial_value_of{ident $self} == 0) {
	    my $molarity = $initial_value_of{ident $self};
	    return $molarity;
	}

	if ($self->get_initial_value_units() =~ /molecules/ &&
	    $compartment_volume eq "NOT_SPECIFIED") {
	    print "ERROR: need to specify compartment volume to convert initial conditions to molarity\n";
	    exit(1);
	}
	if ($self->get_initial_value_units() eq "molecules") {
	    my $molarity = $initial_value_of{ident $self} / $compartment_volume / $AVOGADRO;
	    return $molarity;
	}
	if ($self->get_initial_value_units() eq "uM") {
	    my $molarity = $initial_value_of{ident $self} * 1.0e-6;
	    return $molarity;
	}
	if ($self->get_initial_value_units() eq "M") {
	    my $molarity = $initial_value_of{ident $self};
	    return $molarity;
	}
	
	print "ERROR: internal error in get_initial_value_in_molecules(), exiting....\n";
	exit(1);
    }

}

# TESTING
sub run_testcases {
    print "Testing class: Node\n";

    print "Creating node object: ";
    my $node_ref = Node->new({
	name => "A",
	index => 0,
      });
    print $node_ref->_DUMP();

    print "Done testing class: Node\n";
}

# Package BEGIN must return true value
return 1;


