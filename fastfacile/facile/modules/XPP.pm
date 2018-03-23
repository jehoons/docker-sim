###############################################################################
# File:     XPP.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Export input files required for simulation with XPP.
##############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

package XPP;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

# these subroutines are imported when you use XPP.pm
@EXPORT = qw(
	     export_XPP_file
	    );

#######################################################################################
# INSTANCE METHODS
#######################################################################################

#---------------------------------------------------#
# Prints the input files required for XPP           #
# ODE simulations.                                  #
#---------------------------------------------------#
sub export_XPP_file {
    my $self = shift;

    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $config_ref = $self->get_config_ref();
    my $compartment_volume = $config_ref->{compartment_volume};
    my @xpp_config=@{$config_ref->{compartment_volume}};

    my $print;  # returns ode definition

    # construct lists of nodes and variables to print out
    my @free_nodes = $node_list_ref->get_ordered_free_node_list();
#    my @free_node_names = map ($_->get_name(), @free_nodes);
    my @variables = $variable_list_ref->get_list();
    my @constant_rate_params = grep (($_->get_type() =~ /^(rate)|(other)$/ &&
				      $_->get_is_expression_flag() == 0), @variables);
    my @constant_rate_param_names = map($_->get_name(), @constant_rate_params);
    my @moiety_totals = grep ($_->get_type() eq "moiety_total", @variables);
    my @constrained_node_expressions = grep ($_->get_type() eq "constrained_node_expression",
					     @variables);
    my @rate_expressions = grep ($_->get_type() =~ /^(rate)|(other)$/ &&
				 $_->get_is_expression_flag() == 1, @variables);

    # rate constants
    $print .= "# constants\n";
    foreach my $variable_ref (@constant_rate_params) {
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $variable_dimension = $variable_ref->get_dimension();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$print .= "par $variable_name=$variable_value\n";
    }
    $print .= "\n";

    # moiety totals, e.g. E_moiety = 123 (mol/L)
    $print .= "# moiety totals\n" if (@moiety_totals);
    foreach my $variable_ref (@moiety_totals) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$print .= "par $variable_name=$variable_value\n";
    }
    $print .= "\n";

    # contrained node expressions, e.g. E = C - E_moiety
    $print .= "# dependent species\n" if (@constrained_node_expressions);
    foreach my $variable_ref (@constrained_node_expressions) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$print .= "$variable_name=$variable_value\n";
    }
    $print .= "\n";

    # rate expressions
    $print .= "# expressions\n" if (@rate_expressions);
    foreach my $variable_ref (@rate_expressions) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$print .= "$variable_name=$variable_value\n";
    }
    $print .= "\n";

    # print out differential equations for the free nodes
    $print .= "# differential equations for independent species\n";
    for (my $j = 0; $j < @free_nodes; $j++) {
	my $node_ref = $free_nodes[$j];
	my $node_name = $node_ref->get_name();

	my $ode_rhs;

	# print positive terms
	my @create_reactions = $node_ref->get_create_reactions();
	for(my $i = 0; $i < @create_reactions; $i++){
	    my $reaction_ref = $create_reactions[$i];
	    my $velocity = $reaction_ref->get_velocity();
	    # rhs can not begin with +
	    $ode_rhs .= ($i == 0) ? " $velocity " : "+ $velocity ";
	}
	# print negative terms
	my @destroy_reactions = $node_ref->get_destroy_reactions();
	foreach my $reaction_ref (@destroy_reactions) {
	    my $velocity = $reaction_ref->get_velocity();
	    $ode_rhs .= "- $velocity ";
	}
	if (defined $ode_rhs) {
	    $print .= "$node_name\'=$ode_rhs\n";
	} else {
	    $print .= "$node_name\'=0\n";
	}
    }
    $print .= "\n";

   # print initial values
    $print .= "# initial values (free nodes only)\n";
    foreach my $node_ref (@free_nodes) {
	my $node_name = $node_ref->get_name();
	my $initial_value = $node_ref->get_initial_value_in_molarity($compartment_volume);
	$print .= "init $node_name=$initial_value\n";
    }

    # print configuration stuff
    if(@xpp_config){
	$print .= "\n";
	foreach my $conf_line (@xpp_config){
	    $print .= "$conf_line\n";
	}
    }
    $print .= "done\n";
    return ($print);
}

1;  # don't remove -- req'd for module to return true

