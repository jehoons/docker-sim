###############################################################################
# File:     Matlab.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Export model in Matlab format.
##############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

package Matlab;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

# these subroutines are imported when you use Matlab.pm
@EXPORT = qw(
	     export_matlab_files
	    );

#######################################################################################
# INSTANCE METHODS
#######################################################################################

#---------------------------------------------------#
# Prints the input files required for Matlab        #
# ODE simulations.  There are 4 files generated.    #
#---------------------------------------------------#
sub export_matlab_files {
    my $self = shift;

    my %args = (
	output_file_prefix => undef,
	split_flag => 0,
	@_,
       );

    my $output_file_prefix = $args{output_file_prefix};
    my $split_flag = $args{split_flag};

    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $ode_file_contents;			# ode definition
    my $driver_file_contents;			# ode driver (main function)
    my $species_index_mapper_file_contents;     # species index mapping function
    my $rate_index_mapper_file_contents;        # rate index mapping function
    my $IC_file_contents = "";                  # species initial conditions file
    my $R_file_contents = "";                   # rate constants file

    # get configuration vars affecting Matlab output
    my $config_ref = $self->get_config_ref();
    my $compartment_volume = $config_ref->{compartment_volume};
    my $tf = $config_ref->{tf};
    my $tv = $config_ref->{tv};
    my $tk = $config_ref->{tk};
    my $solver = $config_ref->{solver};
    my $solver_options = $config_ref->{solver_options};
    my $ode_event_times = $config_ref->{ode_event_times};
    my $SS_timescale = $config_ref->{SS_timescale};
    my $SS_RelTol = $config_ref->{SS_RelTol};
    my $SS_AbsTol = $config_ref->{SS_AbsTol};
    my $plot_flag = $config_ref->{plot_flag};

    # construct lists of nodes and variables to print out
    my @free_nodes = $node_list_ref->get_ordered_free_node_list();
    my @free_node_names = map ($_->get_name(), @free_nodes);
    my @variables = $variable_list_ref->get_list();
    my @constant_rate_params = grep (($_->get_type() =~ /^(rate)|(other)$/ &&
				      $_->get_is_expression_flag() == 0), @variables);
    my @constant_rate_param_names = map($_->get_name(), @constant_rate_params);
    my @moiety_totals = grep ($_->get_type() eq "moiety_total", @variables);
    my @constrained_node_expressions = grep ($_->get_type() eq "constrained_node_expression",
					     @variables);
    my @rate_expressions = grep ($_->get_type() =~ /^(rate)|(other)$/ &&
				 $_->get_is_expression_flag() == 1, @variables);

    #********************************************************#
    # generate ode definition                                #
    #********************************************************#
    # ODE function
    # default
    $ode_file_contents .= "function dydt = ".$output_file_prefix."_odes(t, y, rateconstants)\n\n";
    $ode_file_contents .= "global event_flags;\nglobal event_times\n\n" if defined $ode_event_times;

    # Clock tick
    if ($tk != -1) {
	$ode_file_contents .= "persistent last_tick\n";
	$ode_file_contents .= "\n";
	$ode_file_contents .= "if (isempty(last_tick))\n";
	$ode_file_contents .= "  last_tick = 0;\n";
	$ode_file_contents .= "  tic;\n";
	$ode_file_contents .= "end\n";
	$ode_file_contents .= "\n";
	$ode_file_contents .= "if (t - last_tick > $tk)\n";
	$ode_file_contents .= "  str = sprintf('sim time is t=%f, elapsed time=%f', t, toc);\n";
	$ode_file_contents .= "  disp (str)\n";
	$ode_file_contents .= "  last_tick = t;\n";
	$ode_file_contents .= "end\n";
	$ode_file_contents .= "\n";
    }
	
    # map state vector to free nodes
    $ode_file_contents .= "% state vector to node mapping\n" if (@constant_rate_params);
    for (my $j = 0; $j < @free_nodes; $j++) {
	my $node_ref = $free_nodes[$j];
	my $node_name = $node_ref->get_name();
	$ode_file_contents .= "$node_name = y(".($j+1).");\n";
    }	
    $ode_file_contents .= "\n";

    # ordinary rate constants, e.g. binary forward rate of kf1=1e6 (M^-1 s^-1)
    $ode_file_contents .= "% constants\n" if (@constant_rate_params);
    for (my $i = 0; $i < @constant_rate_params; $i++) {
	my $variable_ref = $constant_rate_params[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$ode_file_contents .= "$variable_name = rateconstants(".($i+1).");\n";
    }
    $ode_file_contents .= "\n";

    # moiety totals, e.g. E_moiety = 123 (mol/L)
    $ode_file_contents .= "% moiety totals\n" if (@moiety_totals);
    foreach my $variable_ref (@moiety_totals) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$ode_file_contents .= "$variable_name = $variable_value;\n";
    }
    $ode_file_contents .= "\n";

    # contrained node expressions, e.g. E = C - E_moiety
    $ode_file_contents .= "% dependent species\n" if (@constrained_node_expressions);
    foreach my $variable_ref (@constrained_node_expressions) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$ode_file_contents .= "$variable_name = $variable_value;\n";
    }
    $ode_file_contents .= "\n";

    # rate expressions
    $ode_file_contents .= "% expressions\n" if (@rate_expressions);
    foreach my $variable_ref (@rate_expressions) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$ode_file_contents .= "$variable_name = $variable_value;\n";
    }
    $ode_file_contents .= "\n";

    # print out differential equations for the free nodes
    $ode_file_contents .= "% differential equations for independent species\n";
    for (my $j = 0; $j < @free_nodes; $j++) {
	my $node_ref = $free_nodes[$j];
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
	    $ode_file_contents .= "dydt(".($j+1).")= $ode_rhs;\n";
	} else {
	    $ode_file_contents .= "dydt(".($j+1).")= 0;\n";
	}
    }
    $ode_file_contents .= "dydt = dydt(:);\n\n";

    #********************************************************#
    # generate ode driver                                    #
    #********************************************************#	

    # print initial values
    $IC_file_contents .= "% initial values (free nodes only)\n";
    foreach my $node_ref (@free_nodes) {
	my $node_name = $node_ref->get_name();
	my $initial_value = $node_ref->get_initial_value_in_molarity($compartment_volume);
	$IC_file_contents .= "$node_name = $initial_value;\n";
    }

    # vectorize initial values, printing species in lines of length $linelength
    my $length = @free_node_names;
    my $linelength = 8;
    my $no_lines = int($length/$linelength);
    $IC_file_contents .= "ivalues = [";
    if ($no_lines == 0) {
	$IC_file_contents .= "@free_node_names";
    } else {
	my ($start, $end);
	for (my $j = 0; $j < $no_lines; $j++) {
	    $start= $j * $linelength;
	    $end= $start + $linelength - 1;
	    $IC_file_contents .= "@free_node_names[$start...$end] ...\n\t";
	}
	$start = $end + 1;
	$end = $length - 1;
	$IC_file_contents .= "@free_node_names[$start...$end]";
    }
    $IC_file_contents .= "];\n\n";

    # if splitting, source the IC file, else incorporate directly in driver
    if (!$split_flag) {
	$driver_file_contents .= $IC_file_contents;
    } else {
	$driver_file_contents .= "% initial values (free nodes only)\n";
	$driver_file_contents .= "${output_file_prefix}_S;\n\n";
    }

    # rate constants 
    $R_file_contents .= "% rate constants\n";
    foreach my $variable_ref (@constant_rate_params) {
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $variable_dimension = $variable_ref->get_dimension();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$R_file_contents .= "$variable_name= $variable_value;\n";
    }
    $R_file_contents .= "rates= [";
    $length = @constant_rate_params;
    $linelength = 12;
    $no_lines = int($length/$linelength);
    if ($no_lines == 0) {
	$R_file_contents .= "@constant_rate_param_names";
    } else {
	my ($start, $end);
	for (my $j = 0; $j < $no_lines; $j++) {
	    $start= $j * $linelength;
	    $end= $start + $linelength - 1;
	    $R_file_contents .= "@constant_rate_param_names[$start...$end] ...\n\t";
	}
	$start= $end+1;
	$end= $length-1;
	$R_file_contents .= "@constant_rate_param_names[$start...$end]";
    }
    $R_file_contents .= "];\n\n";

    # if splitting, source the IC file, else incorporate directly in driver
    if (!$split_flag) {
	$driver_file_contents .= $R_file_contents;
    } else {
	$driver_file_contents .= "% rate constants\n";
	$driver_file_contents .= "${output_file_prefix}_R;\n\n";
    }

    # call ODE function
    $driver_file_contents .= "% time interval\n";
    $driver_file_contents .= "t0= 0;\n";
    $driver_file_contents .= "tf= $tf;\n";
    $driver_file_contents .= "\n% call solver routine \n";
    $driver_file_contents .= "global event_times;\n" if (defined $ode_event_times);
    $driver_file_contents .= "global event_flags;\n" if (defined $ode_event_times);
    if (defined $ode_event_times) {
	my $ode_events = $ode_event_times;
	# translate ~ to '0' or '-' to conform with ode_event.m convention
	$ode_events =~ s/~\s+/0 /g;   # tilde followed by whitespace becomes 0
	$ode_events =~ s/~$/0/g;      # tilde as last character becomes 0
	$ode_events =~ s/~/-/g;       # any other tilde becomes a '-'
	$driver_file_contents .= ("[t, y, intervals]= ${output_file_prefix}_ode_event(".
			       "\@${solver}, \@${output_file_prefix}_odes, $tv, ivalues, $solver_options, ".
				  "[$ode_events], [$SS_timescale], [$SS_RelTol], [$SS_AbsTol], rates);\n\n");
    } else {
	$driver_file_contents .= "[t, y]= $solver(\@${output_file_prefix}_odes, $tv, ivalues, $solver_options, rates);\n\n";
    }

    $driver_file_contents .= "% map free node state vector names\n";
    for (my $j = 0; $j < @free_node_names; $j++) {
	$driver_file_contents .= "$free_node_names[$j] = y(:,".($j+1)."); ";
	if (($j % 10) == 9) {
	    $driver_file_contents .= "\n";
	}
    }
    $driver_file_contents .= "\n\n";

    # moiety totals, e.g. E_moiety = 123 (mol/L)
    $driver_file_contents .= "% moiety totals\n" if (@moiety_totals);
    foreach my $variable_ref (@moiety_totals) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$driver_file_contents .= "$variable_name = $variable_value;\n";
    }
    $driver_file_contents .= "\n";

    # contrained node expressions, e.g. E = C - E_moiety
    $driver_file_contents .= "% compute constrained nodes\n" if (@constrained_node_expressions);
    foreach my $variable_ref (@constrained_node_expressions) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $is_expression_flag = $variable_ref->get_is_expression_flag();
	$driver_file_contents .= "$variable_name = $variable_value;\n";
    }
    $driver_file_contents .= "\n";

    # plot free nodes
    my $fig_num = 100;
    # comment out plot commands if user didn't specify -P on command line
    my $plot_prefix = ($plot_flag ? "" : "%");
    my @probed_nodes = grep ($_->get_probe_flag(), @free_nodes);
    $driver_file_contents .= "% plot free nodes\n" if (@probed_nodes);
    for (my $j = 0; $j < @probed_nodes; $j++) {
	my $node_ref = $probed_nodes[$j];
	my $node_name = $node_ref->get_name();
	my $title = length($node_name) <= 40 ? $node_name : substr($node_name, 0, 40).".....(truncated)";
	$title =~ s/_/\\_/g;  # escape underscore for Matlab (otherwise interprets as subscript)
	# plot command uses convert routine
	$driver_file_contents .= "${plot_prefix}figure(".$fig_num++.");plot(t, $node_name);title(\'$title\')\n";
    }
    $driver_file_contents .= "\n";

    # plot expressions
    my @probe_expressions = grep ($_->get_probe_flag(), @variables);
    $driver_file_contents .= "% plot expressions\n" if (@probe_expressions);
    for (my $j = 0; $j < @probe_expressions; $j++) {
	my $probe_ref = $probe_expressions[$j];
	my $probe_name = $probe_ref->get_name();
	my $probe_value = $probe_ref->get_value();
	# plot command uses convert routine
	my $title = length($probe_value) <= 40 ? $probe_value : substr($probe_value, 0, 40).".....(truncated)";
	$title = "$probe_name=$title";
	$title =~ s/_/\\_/g;  # escape underscore for Matlab (otherwise interprets as subscript)
	$driver_file_contents .= "$probe_name = $probe_value;\n";
	$driver_file_contents .= "${plot_prefix}figure(".$fig_num++."); plot(t, $probe_name);title(\'$title\');\n";
    }
    $driver_file_contents .= "\n";

    # please don't remove this 'done' message
    $driver_file_contents .= "% issue done message for calling/wrapper scripts\n";
    $driver_file_contents .= "disp('Facile driver script done');\n\n";

    #********************************************************#
    # generate species conversion function                   #
    #********************************************************#	

    $species_index_mapper_file_contents .= "function n= ".$output_file_prefix."_s(a)\n\n";
    for (my $j = 0; $j < @free_node_names; $j++) {
	$species_index_mapper_file_contents .= ($j == 0) ? "if" : "elseif";
	$species_index_mapper_file_contents .= " strcmp(a, '".$free_node_names[$j]."')\n";
	$species_index_mapper_file_contents .= "\tn= ".($j+1).";\n";
    }
    $species_index_mapper_file_contents .= "else\n\tdisp('ERROR!');\n";
    $species_index_mapper_file_contents .= "\tn= -1;\nend;";

    #********************************************************#
    # generate rates conversion function                     #
    #********************************************************#	

    $rate_index_mapper_file_contents .= "function n= ".$output_file_prefix."_r(a)\n\n";
    for (my $j = 0; $j < @constant_rate_param_names; $j++) {
	$rate_index_mapper_file_contents .= ($j == 0) ? "if" : "elseif";
	$rate_index_mapper_file_contents .= " strcmp(a, '".$constant_rate_param_names[$j]."')\n";
	$rate_index_mapper_file_contents .= "\tn= ".($j+1).";\n";
    }
    $rate_index_mapper_file_contents .= "else\n\tdisp('ERROR!');\n";
    $rate_index_mapper_file_contents .= "\tn= -1;\nend;"; 

    return (
	$ode_file_contents,
	$driver_file_contents,
	$species_index_mapper_file_contents,
	$rate_index_mapper_file_contents,
	$IC_file_contents,
	$R_file_contents,
       );
}

1;  # don't remove -- req'd for module to return true

