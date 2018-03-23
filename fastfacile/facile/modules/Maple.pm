###############################################################################
# File:     Maple.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Export model in Maple format.
##############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

package Maple;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

# these subroutines are imported when you use Mathematica.pm
@EXPORT = qw(
	     export_maple_file
	    );

#######################################################################################
# INSTANCE METHODS
#######################################################################################

#---------------------------------------------------#
# Prints the input file for Maple                   #
#---------------------------------------------------#
sub export_maple_file {
    my $self = shift;

    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $compartment_volume = $self->get_config_ref()->{compartment_volume};

    my $file_contents = "";

    my @free_nodes = $node_list_ref->get_ordered_free_node_list();
    my @variables = $variable_list_ref->get_list();
    my @constant_rate_params = grep (($_->get_type() =~ /^(rate)|(other)$/ &&
				      $_->get_is_expression_flag() == 0), @variables);
    my @moiety_totals = grep ($_->get_type() eq "moiety_total", @variables);
    my @constrained_node_expressions = grep ($_->get_type() eq "constrained_node_expression",
					     @variables);
    my @rate_expressions = grep ($_->get_type() =~ /^(rate)|(other)$/ &&
				 $_->get_is_expression_flag() == 1, @variables);

    # initial values
    $file_contents .= "# initial values\n";
    for(my $j = 0; $j < @free_nodes; $j++){
	my $node_name = $free_nodes[$j]->get_name();
	my $initial_value = $free_nodes[$j]->get_initial_value_in_molarity($compartment_volume);
	$file_contents .= sprintf("i${node_name} := $initial_value;\n");
    }

    # ordinary rate constants, e.g. binary forward rate of kf1=1e6 (M^-1 s^-1)
    $file_contents .= "\n# constants\n" if (@constant_rate_params);
    for (my $i=0; $i < @constant_rate_params; $i++) {
	my $variable_ref = $constant_rate_params[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$file_contents .= "$variable_name := $variable_value;\n";
    }

    # moiety totals, e.g. E_moiety = 123 (mol/L)
    $file_contents .= "\n# moiety totals\n" if (@moiety_totals);
    for (my $i=0; $i < @moiety_totals; $i++) {
	my $variable_ref = $moiety_totals[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$file_contents .= "$variable_name := $variable_value;\n";
    }

    # contrained node expressions, e.g. E = C - E_moiety
    $file_contents .= "\n# dependent species\n" if (@constrained_node_expressions);
    for (my $i=0; $i < @constrained_node_expressions; $i++) {
	my $variable_ref = $constrained_node_expressions[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$file_contents .= "$variable_name := $variable_value;\n";
    }

    # rate expressions
    $file_contents .= "\n# expressions\n" if (@rate_expressions);
    for (my $i=0; $i < @rate_expressions; $i++) {
	my $variable_ref = $rate_expressions[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();

	my $expression = $variable_value;
	# !!! need to translate matlab expressions to mathematica expressions ???
	$file_contents .= "$variable_name := $expression;\n";
    }

    # print out differential equations for the free nodes
    $file_contents .= "\n# ode for independent species\n";
    foreach my $node_ref (@free_nodes) {
	my $node_name = $node_ref->get_name();
	my $ode_rhs;
	# print positive terms
	my @create_reactions = $node_ref->get_create_reactions();
	foreach my $reaction_ref (@create_reactions) {
	    my $velocity = $reaction_ref->get_velocity();
	    $ode_rhs .= "+ $velocity ";
	}
	# print negative terms
	my @destroy_reactions = $node_ref->get_destroy_reactions();
	foreach my $reaction_ref (@destroy_reactions) {
	    my $velocity = $reaction_ref->get_velocity();
	    $ode_rhs .= "- $velocity "; 
	}
	if (defined $ode_rhs) {
	    $file_contents .= "d${node_name}dt := $ode_rhs;\n";
	} else {
	    $file_contents .= "d${node_name}dt := 0;\n";
	}
    }

    return $file_contents;
}

1;  # don't remove -- req'd for module to return true

