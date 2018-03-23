###############################################################################
# File:     Parser.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: These Model class methods parse an input file and
#           store info in Model object.
#
###############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

package Parser;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

# these subroutines are imported when you use Parser.pm
@EXPORT = qw(
	     read_and_preprocess_input_file
	     parse_eqn_section
	     parse_equation
	     parse_rate
	     parse_init_section
	     parse_moiety_section
	     parse_bifurc_param_section
	     parse_promoter_section
	     parse_config_section
	     parse_probe_section
	    );

use Globals;
use Utils;

use Tables;

#######################################################################################
# INSTANCE METHODS
#######################################################################################

#--------------------------------------------------- #
# Pre-process the file and dump into line buffer,    #
# removing comments (starting with "//" or "#"), and #
# empty lines.  Dump each section into corresponding #
# key of the file_buffer_ref hash.  This means other #
# parsing routines can assume they are processing    #
# the appropriate section, simplifying the code.     #
#----------------------------------------------------#
sub read_and_preprocess_input_file {
    my $self = shift;
    my $input_file_name = shift;

    $self->set_input_file_name($input_file_name);

    my $file_buffer_ref = {};  # declare hash ref to buffer file sections
    $self->set_file_buffer_ref($file_buffer_ref);

    my $input_file_handle;
    if ($input_file_name eq "-") {
	$input_file_handle = *STDIN;
    } elsif (-e $input_file_name) {
	open INPUT_FILE, "< $input_file_name" or die "ERROR: Can't open file $input_file_name\n";
	$input_file_handle = *INPUT_FILE
    }

    # the section that the input file is assumed to begin with should be first element of array
    my @section_names = ("EQN", "INIT", "MOIETY", "BIFURC_PARAM", "CONFIG", "PROMOTER", "PROBE");

    # since file is assumed to start with EQN section,
    # it should be first in section_names array
    my $current_section = $section_names[0];

    LINES: while (<$input_file_handle>) {
	$_ =~ s/^\s+//;         # Strip out leading whitespace
	$_ =~ s/\s+$//;         # Strip out trailing whitespace (including \n)
	$_ =~ s/\s*\#.*//;      # Strip out trailing (#)  comment and whitespace
	$_ =~ s/\s*\/\/.*//;    # Strip out trailing (//) comment and whitespace
	next if($_ =~ /^$/);    # Strip out empty lines
	
	my $line = $_;

	# check if new section
	foreach my $section (@section_names) {
	    if ($line =~ /$section\:?/) {
		$current_section = $section;
		next LINES;
	    }
	}

	push @{$file_buffer_ref->{$current_section}}, $line;
	push @{$file_buffer_ref->{ALL_SECTIONS}}, $line;
    }
    close($input_file_handle);

    if (!@{$file_buffer_ref->{ALL_SECTIONS}}) {
	print "Warning: input file appears to be empty (comments excepted); exiting...\n" if !$quiet;
	exit(0);
    }
    if (!defined $file_buffer_ref->{EQN}) {
	print "Warning: there appear to be no reaction equations in this file\n" if !$quiet;
    }
    if (!defined $file_buffer_ref->{INIT}) {
	print "Warning: there are no initial conditions specified in this file\n" if !$quiet;
    }
}

#---------------------------------------------------#
# Parse the EQN sections of the file line by line   #
#---------------------------------------------------#
sub parse_eqn_section {
    my $self = shift;

    my $file_buffer_ref = $self->get_file_buffer_ref();
    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    foreach my $line (@{$file_buffer_ref->{EQN}}) {
	if(($line =~ /<[-=]/) || ($line =~ /[-=]>/)) {  # if eq'n has an eq'n arrow...
	    $self->parse_equation(SOURCE_LINE => $line);
	} elsif($line =~ /^\s*node\s+(.*\S)\s*$/) {  # explicit node declaration
	    # create nodes if they don't already exist
	    foreach my $node_name (split /[\s|,|;]+/, $1) {
		my $node_ref = $node_list_ref->lookup_by_name($node_name);
		if (!defined $node_ref) {
		    $node_ref = $node_list_ref->new_node({name => $node_name});
		} else {
		    print "Warning: node $node_name is already defined before explicit declaration\n";
		}
	    }
	} elsif($line =~ /^\s*(variable|parameter)\s+(\S+)\s*=\s*(\S.*)$/) {  # explicit variable declaration
	    my $name = $2;
	    my $value = $3;

	    my $variable_ref;

	    # now save constant if not already defined, otherwise check value didn't change
	    if (!defined $variable_list_ref->lookup_by_name($name)) {
		my $is_expression_flag;

		if (is_numeric($value)) {
		    $is_expression_flag = 0;
		} else {
		    # not a number, so must be a (possibly quoted) expression
		    if ($value =~ /^\"(.*)\"$/) {
			# get rid of quotes
			$value = $1;
		    }
		    $is_expression_flag = 1;
		}
		# store the value
		$variable_ref = $variable_list_ref->new_variable({
		    name => $name,
		    value => $value,
		    type => "other",
		    is_expression_flag => $is_expression_flag,
		    dimension => "unknown",
		    source_line => $line,
		});
	    } else {
		$variable_ref = $variable_list_ref->lookup_by_name($name);
		if (!$variable_ref->compare_value($value)) {
		    my $previous_value = $variable_list_ref->lookup_by_name($name)->get_value();
		    print "ERROR:  You are trying to redefine $name from a previous value of $previous_value\n";
		    print "  --> $line\n";
		    exit(1);
		}
	    }
	} elsif($line =~ /^table\s+(\S+)\s*=\s*\((\S.*)\)$/) {  # table definition
	    my $table_name = $1;
	    my $table_values = $2;
	    define_table($table_name, split(/[, ]+/, $table_values));
	} else {
	    print "Warning: line does not appear to be a reaction equation, node or variable declaration\n --> $line\n" if (!$quiet);
	}
    }
}

#--------------------------------------------------------------------------#
# Parses an equation string of the form:                                   #
#    (substrates) -> (products);   (rate assignement)                      #
#    (products)  <-  (substrates); (rate assignement)                      #
#    (products)  <-> (substrates); (rate assignement); (rate assignement)  #
#    (substrates) => (products);   (rate assignement)                      #
#    (products)  <=  (substrates); (rate assignement)                      #
#    (products)  <=> (substrates); (rate assignement); (rate assignement)  #
#                                                                          #
# Substrates and products are strings of the form "A B..." or "A+B..."     #
#                                                                          #
# E.g.                                                                     #
#    A   B <-  C; b=1.0                                                    #
#    X + Y <=> Z; c="2.0*X*Y"; d="0.1*Z"                                   #
#                                                                          #
# Creates new reaction object with associated information.                 #
# Reversible equations generate 2 reactions by recursive calling.  Creates #
# creates node objects as new nodes are found.  Calls parse_rate() to      #
# process associated reaction rates.                                       #
#--------------------------------------------------------------------------#
sub parse_equation {
    my $self = shift;

    my %args = (
        # default values
        SOURCE_LINE    => undef,
        IS_RATE_LAW    => 0,
        @_,        # argument pair list overwrites defaults
    );

    if (keys %args != 2) {
        print "ERROR: parse_equation -- unknown argument in ". (join ", ", (sort keys %args)) ."\n";
        exit(1);
    }

    if (!defined $args{SOURCE_LINE}) {
	print "ERROR: undefined argument SOURCE_LINE in call to parse_equation\n";
	exit(1);
    }

    my $reaction_list_ref = $self->get_reaction_list();
    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $source_line = $args{SOURCE_LINE};

    # indicates that the equation is a "rate-law" and not a
    # "mass-action" equation
    my $is_rate_law = $args{IS_RATE_LAW};

    # remove extra spaces from line (in case we print it)
    $source_line =~ s/\s\s/ /g;

    my @array = split(/;/, $source_line);
    my $reaction = $array[0];
    my $rate1_assignment = $array[1];
    my $rate2_assignment = $array[2];

    my ($rate1_ref, $rate2_ref);

    my $rate_dimension;

    if (!defined $rate1_assignment) { # need at least one rate constant
	print "ERROR: a rate constant is required in $source_line\n";
	exit(1);
    }

    if (defined $rate2_assignment) { # but a 2nd one only for reversible reactions
	if ($reaction !~ /\s*(.*)<[-=]>\s*(.*)/) {
	    print "Warning: a 2nd rate constant was specified when none required in $source_line\n" if (!$quiet);
	    $rate2_ref = $self->parse_rate($source_line,$rate2_assignment); # but parse it anyway
	}
    }

    if($reaction =~ /\s*(.*)<->\s*(.*)/){ 
	if (!defined $rate2_assignment) {
	    print "ERROR: a 2nd rate constant is required in $source_line\n";
	    exit(1);
	}
	$self->parse_equation(SOURCE_LINE => "$1 -> $2; $rate1_assignment");
	$self->parse_equation(SOURCE_LINE => "$2 -> $1; $rate2_assignment");
    }
    elsif($reaction =~ /\s*(.*)<=>\s*(.*)/){
	if (!defined $rate2_assignment) {
	    print "ERROR: a 2nd rate constant is required in $source_line\n";
	    exit(1);
	}
	$self->parse_equation(SOURCE_LINE => "$1 => $2; $rate1_assignment");
	$self->parse_equation(SOURCE_LINE => "$2 => $1; $rate2_assignment");
    }
    elsif($reaction =~ /\s*(.*)=>\s*(.*)/ && !$is_rate_law){
	$self->parse_equation(SOURCE_LINE => "$1 => $2; $rate1_assignment", IS_RATE_LAW => 1);
    }
    elsif($reaction =~ /\s*(.*)<=\s*(.*)/ && !$is_rate_law){
	$self->parse_equation(SOURCE_LINE => "$2 => $1; $rate1_assignment", IS_RATE_LAW => 1);
    }
    elsif($reaction =~ /\s*(.*)<-\s*(.*)/){
	$self->parse_equation(SOURCE_LINE => "$2 -> $1; $rate1_assignment");
    }
    elsif($reaction =~ /\s*(.*)[-=]>\s*(.*)/){
	# extract substrates/product lists, removing 'null', and splitting on whitespace or '+' characters
	my @substrate_names = grep(!/(null)|\+/, split(/[\s\+]+/,$1));
	my @product_names = grep(!/(null)|\+/, split(/[\s\+]+/,$2));

	print "parsing reaction: $source_line\n" if ($verbose);

	# extract rate name and value
	$rate_dimension = @substrate_names;

	# extract easystoch dynamic rate order if present
	my $dynrate_order = 0;
	if ($rate1_assignment =~ s/(\S+)(\:(\d))/$1/) {
	    $dynrate_order = $3;
	}

	$rate1_ref = $self->parse_rate($source_line, $rate1_assignment, $rate_dimension);
	
	# create and initialize reaction object
	my $reaction_ref = $reaction_list_ref->new_reaction({
	    substrate_names_ref => \@substrate_names,
	    product_names_ref => \@product_names,
	    rate_ref => $rate1_ref,
	    source_line => $source_line,
	    is_rate_law_flag => $is_rate_law,
	    easystoch_dynrate_order => $dynrate_order,
	});

	my $reaction_index = $reaction_ref->get_index();
	
	# create nodes if they don't already exist, and create/update associated list of reactions
	foreach my $node_name (@substrate_names) {
	    my $node_ref = $node_list_ref->lookup_by_name($node_name);
	    if (!defined $node_ref) {
		$node_ref = $node_list_ref->new_node({name => $node_name});
	    }
	    $node_ref->add_destroy_reaction($reaction_ref);
	}
	foreach my $node_name (@product_names) {
	    my $node_ref = $node_list_ref->lookup_by_name($node_name);
	    if (!defined $node_ref) {
		$node_ref = $node_list_ref->new_node({name => $node_name});
	    }
	    $node_ref->add_create_reaction($reaction_ref);
	}
    }
    else{
	print "ERROR: reaction \"$source_line\" not in correct form\n";
	exit(1);
    }
}


#---------------------------------------------------#
# Parses rate assignement strings of the form       #
#    f1=2e1             (rate constant)             #
#    f2=1.1                                         #
#    f2                 (re-use a rate)             #
#    f3=f2              (re-use a rate)             #
#    f4="square(....)"  (rate expression)           #
# Any amount of whitespace is legal.                #
# Performs appropriate substitution when a rate     #
# constant is re-used.  Creates a variable object   #
# and returns reference.                            #
#---------------------------------------------------#
sub parse_rate {
    my $self = shift;

    my $source_line = shift;
    my $rate_assignment = shift;
    my $dimension = shift;

    my $variable_list_ref = $self->get_variable_list();

    my $rate_variable_ref;

    if ($rate_assignment =~ /\s*(\w+)\s*(=\s*(.+?)\s*)?$/) {
	my ($name, $value);
	$name = $1;
	if (defined $3) {
	    $value = $3
	}
	# check if rate constant is an already existing constant
	# (e.g. a + b -> c; f1; f2 # here f1&f2 already exist and have values)
	if ((!defined $value) && (defined $variable_list_ref->lookup_by_name($name))) {
	    $value = $variable_list_ref->lookup_by_name($name)->get_value();
	}
	if (!defined $value) {
	    print "Warning: missing value for rate constant in assignment $source_line\n";
	    $value = 0;
	}
	# now save variable if not already defined, otherwise check value didn't change
	if (!defined $variable_list_ref->lookup_by_name($name)) {
	    my $is_expression_flag;
	    if (is_numeric($value)) {
		$is_expression_flag = 0;
	    } else {
		# not a number, so must be a (possibly quoted) expression
		if ($value =~ /^\"(.*)\"$/) {
		    # get rid of quotes
		    $value = $1;
		}
		$is_expression_flag = 1;
	    }
	    # issue warning if the constant is zero, but only check if not an expression
	    # (since we can't compare strings with == operator)
	    if (($is_expression_flag == 0) && ($value == 0.0)) {
		print "Warning: rate $name has value of zero\n" if (!$quiet);
	    }
	    # store the value
	    $rate_variable_ref = $variable_list_ref->new_variable({
		name => $name,
		value => $value,
		type => "rate",
		is_expression_flag => $is_expression_flag,
		dimension => $dimension,
		source_line => $source_line,
	    });
	} else {
	    $rate_variable_ref = $variable_list_ref->lookup_by_name($name);
	    if(!$rate_variable_ref->compare_value($value)) {
		my $previous_value = $variable_list_ref->lookup_by_name($name)->get_value();
		print "ERROR:  You are trying to redefine $name from a previous value of $previous_value\n";
		print "  --> $source_line\n";
		exit(1);
	    }

	    # check substrate count associated with rate for inconsistencies in use
	    if (defined $dimension) {
		if ($rate_variable_ref->get_dimension() != $dimension) {
		    print "Warning: you are using rate $name for different reaction types (i.e. unimolecular, bimolecular...)\n";
		    print "Warning: (this means that its dimensions may be incorrect)\n";
		    print "Warning: (if you are **VERY** sure this is OK, use a different name to eliminate this warning)\n";
		}
	    }
	}
    } else {
	print "ERROR: Missing reaction rate constant in equation $source_line\n";
	exit(1);
    }

    return $rate_variable_ref;
}



#----------------------------------------------------------#
# Parses MOIETY section.  The specified variables          #
# will remain free during the constraint identification    #
# procedure unless tagged by letter c, in which case they  #
# will be fixed.                                           #
# Place section anywhere after the equations.              #
# Tag for section is VARIABLES.  Variables specified as:   #
#   MOIETY                                                 #
#   independent A,B                                        #
#   dependent X                                            #
# Here A and B will remain free but X will be              #
# constrained.                                             #
#----------------------------------------------------------#
sub parse_moiety_section {
    my $self = shift;

    my $file_buffer_ref = $self->get_file_buffer_ref();
    my $node_list_ref = $self->get_node_list();

    foreach my $line (@{$file_buffer_ref->{MOIETY}}) {
	if ($line =~ /^\s*dependent\s+(.+)/){
	    foreach my $node_name (split(/[\s|,]+/, $1)) {
		my $node_ref = $node_list_ref->designate_as_nonfree($node_name);
		if (!defined $node_ref) {
		    print "Warning: unknown node $node_name in MOIETY section, ignoring...\n";
		}
	    }
	} elsif ($line =~ /^\s*independent\s+(.+)/) {
	    foreach my $node_name (split(/[\s|,]+/, $1)) {
		my $node_ref = $node_list_ref->designate_as_free($node_name);
		if (!defined $node_ref) {
		    print "Warning: unknown node $node_name in MOIETY section, ignoring...\n";
		}
	    }
	} else {
	    print "ERROR: invalid line in MOIETY section\n";
	    print "--> $line\n";
	    exit(1);
	}
    }
}

#-------------------------------------------------------#
# Parses Bifurcation Parameters section.  The specified #
# parameters will be used by AUTO.                      #
# Place section anywhere after the equations.           #
# Tag for section is BIFURC_PARAM.                      #
# Variables specified as:                               #
#   BIFURC_PARAM                                        #
#   k1, k2                                              #
#   f2                                                  #
#   E_tot     # <-- a moiety total, E must have been    #
#             #     specified as constrained previously #
#-------------------------------------------------------#
sub parse_bifurc_param_section {
    my $self = shift;

    my $file_buffer_ref = $self->get_file_buffer_ref();
    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $line;
    foreach my $line (@{$file_buffer_ref->{BIFURC_PARAM}}) {
	foreach my $param_name (split(/[\s|,]+/, $line)) {
	    my $param_ref = $variable_list_ref->lookup_by_name($param_name);
	    if (defined $param_ref) {
		if ($param_ref->get_is_expression_flag() == 0) {
		    $param_ref->designate_as_bifurcation_parameter();
		} else {
		    print "Warning: cannot designate the rate expression $param_name as a bifurcation parameter, ignoring....\n";
		}
	    } else {
		# if the variable does not exist, it is possible that the user is referring to a moiety,
		# in which case he should have previously specified that the corresponding node is constrained
		if ($param_name =~ /(.*)_tot/) {
		    my $putative_constrained_node_name = $1;
		    my $putative_constrained_node_ref = $node_list_ref->lookup_by_name($putative_constrained_node_name);
		    if (defined $putative_constrained_node_ref && 
			($putative_constrained_node_ref->get_is_nonfree_flag() == 1)) {
			# create the variable
			my $param_ref = $variable_list_ref->new_variable({
			    name => $param_name,
			    value => "to_be_determined",
			    type => "moiety_total",
			    is_expression_flag => 0,
			    dimension => "to_be_determined",
			    source_line => "moiety total variable created by Parser.pm",
			});
			$param_ref->designate_as_bifurcation_parameter();
		    } else {
			print "Warning: referring to moiety $param_name in BIFURC_PARAM section without designating corresponding node as dependent in MOIETY section, ignoring...\n";
		    }
		} else {
		    print "Warning: unknown rate/moiety $param_name in BIFURC_PARAM section, ignoring...\n";
		}
	    }
	}
    }
}

#-----------------------------------------------------#
# Parses initial values section                       #
# Initial value will be of the form:                  #
#    A=2.5                                            #
#    B = 3.2; C=2.5                                   #
# N.B. Initial values of nodes were previously set    #
# to zero above.  Any amount of whitespace is legal.  #
#-----------------------------------------------------#
sub parse_init_section {
    my $self = shift;

    my $file_buffer_ref = $self->get_file_buffer_ref();
    my $node_list_ref = $self->get_node_list();

    foreach my $line (@{$file_buffer_ref->{INIT}}) {
	foreach my $initial_value (split (/;/, $line)) {
	    if ($initial_value =~ /(\w+)\s*(=\s*(.+?))?\s*$/) {
		my $name = $1;
		my $value = $3;
		my $units;

		$value = 0 if (!defined $value);
		if ($value =~ /(.*)uM$/) {
		    $units = "uM";
		    $value = $1;
		} elsif ($value =~ /(.*)M$/) {
		    $units = "M";
		    $value = $1;
		} elsif ($value =~ /(.*)N$/) {
		    $units = "molecules";
		    $value = $1;
		} else {
		    $units = "M"  # default to molar
		}

		my $node_ref = $node_list_ref->lookup_by_name($name);
		
		if (!defined $node_ref) {
		    print "Warning: initial value specified for node $name which does not appear in equations\n" if (!$quiet);
		    next;
		} else {
		    $node_ref->set_initial_value($value);       # will generate appropriate warnings
		    $node_ref->set_initial_value_units($units);
		}
	    } else {
		print "ERROR: invalid line in INIT section\n--> $line\n";
		exit(1);
	    }
	}
    }
}

#-----------------------------------------------------------------------#
# Parses promoter and promoter-complex declarations                     #
# of the form:                                                          #
# Initial value will be of the form:                                    #
#    B=(copy number); promoter_replication_time=(replication time)      #
#    C=3; associated_promoter=B                                         #
# N.B. Initial values of nodes were previously set                      #
# to zero above.  Any amount of whitespace is legal.                    #
#-----------------------------------------------------------------------#
sub parse_promoter_section {
    my $self = shift;

    my $file_buffer_ref = $self->get_file_buffer_ref();
    my $node_list_ref = $self->get_node_list();

    foreach my $line (@{$file_buffer_ref->{PROMOTER}}) {
	my @temp = split(/;/, $line);
	my $node_ref;
	if ($temp[0] =~ /^\s*(\S+)\s*$/) {
	    my $name = $1;
	    $node_ref = $node_list_ref->lookup_by_name($name);
	    if (!defined $node_ref) {
		print "Warning: unknown node $name in PROMOTER section\n" if (!$quiet);
		next;
	    }
	} else {
	    print "ERROR: invalid line in DATA section\n--> $line\n";
	    exit(1);
	}

	if (defined $temp[1]) {
	    if ($temp[1] =~ /^\s*promoter_replication_time\s*(=\s*(.+?))?\s*$/) {
		my $replication_time = $2;
		if (!defined $replication_time) {
		    print "ERROR: you need to give a replication time in $line\n";
		    exit(1);
		}
		$node_ref->set_replication_time($replication_time); # will generate appropriate warnings
	    } elsif ($temp[1] =~ /^\s*associated_promoter\s*(=\s*(.+?))?\s*$/) {
		my $associated_promoter = $2;
		$node_ref->set_associated_promoter($associated_promoter);
		my $promoter_node_ref = $node_list_ref->lookup_by_name($associated_promoter);
		if (!defined $promoter_node_ref) {
		    print "ERROR: promoter node $associated_promoter not found in equations.\n";
		    exit(1);
		}
		if ($promoter_node_ref->is_promoter() == 0) {
		    print "ERROR: Node $associated_promoter has not been defined as a promoter yet.\n";
		    exit(1);
		}
		$promoter_node_ref->add_associated_complex($node_ref);
	    } else {
		print "ERROR: invalid line in PROMOTER section\n--> $line\n";
		exit(1);
	    }
	}
    }
}

# Read CONFIG section and plug in values, unless user already assigned them on command line
sub parse_config_section {
    my $self = shift;

    my $file_buffer_ref = $self->get_file_buffer_ref();
    my $config_ref = $self->get_config_ref();

    foreach my $line (@{$file_buffer_ref->{CONFIG}}) {
	$line =~ s/;$//;   # remove trailing semi-colon
	if ($line =~ /^t_final\s*=\s*(\S+)/) {
	    $config_ref->{tf} = $1 unless $main::opt_t;
	} elsif ($line =~ /compartment_volume\s*=\s*(\S+)/) {
	    $config_ref->{compartment_volume} = $1 unless $main::opt_C;
	} elsif ($line =~ /^t_vector\s*=\s*(\[.*\])/) {
	    $config_ref->{tv} = $1 unless $main::opt_v;
	} elsif ($line =~ /^matlab_ode_solver\s*=\s*(\S+)/) {
	    $config_ref->{solver} = $1 unless $main::opt_l;
	} elsif ($line =~ /^matlab_odeset_options\s*=\s*(\S.*)/) {
	    $config_ref->{solver_options} = $1 unless $main::opt_n;
	} elsif ($line =~ /^event_times\s*=\s*(\S.*)/) {
	    print "ERROR: the config variable event_times is deprecated, ".
	      "use ode_event_times or easystoch_sample_times instead\n";
	    exit(1);
	} elsif ($line =~ /^ode_event_times\s*=\s*(\S.*)/) {
	  $config_ref->{ode_event_times} = $1 unless $main::opt_e;
	} elsif ($line =~ /^SS_timescale\s*=\s*(\S.*)/) {
	    $config_ref->{SS_timescale} = $1;
	} elsif ($line =~ /^SS_RelTol\s*=\s*(\S.*)/) {
	    $config_ref->{SS_RelTol} = $1;
	} elsif ($line =~ /^SS_AbsTol\s*=\s*(\S.*)/) {
	    $config_ref->{SS_AbsTol} = $1;
	} elsif ($line =~ /^easystoch_sample_times\s*{(\S+)}\s*=\s*(\S.*)/) {
	  $config_ref->{easystoch_sample_times}{$1} = $2;
	} elsif ($line =~ /^@/) {
	    push @{$config_ref->{xpp_config}}, $line;
	} else {
	    print "ERROR: invalid line in the CONFIG section\n";
	    print "--> $line\n";
	    if ($line =~ /slow_timescale/) {
	      print "(n.b. slow_timescales has been renamed to SS_timescale)\n";
	    }
	    exit(1);
	}
    }
}

# Read PROBE section and set plot flags on nodes and variables
sub parse_probe_section {
    my $self = shift;

    my $file_buffer_ref = $self->get_file_buffer_ref();
    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    foreach my $line (@{$file_buffer_ref->{PROBE}}) {
	if($line =~ /^probe\s+(\S+)\s*=\s*(\S.*)$/) {
	    # create new variables to be probed
	    my $name = $1;
	    my $value = $2;

	    # get rid of quotes
	    if ($value =~ /^\"(.*)\"$/) {
		# get rid of quotes
		$value = $1;
	    }

	    if (is_numeric($value)) {
		print "ERROR: probe $name cannot be a constant\n";
		exit(1);
	    }

	    my $variable_ref = $variable_list_ref->new_variable({
		name => $name,
		value => $value,
		type => "probe",
		is_expression_flag => 1,
		dimension => "unknown",
		source_line => $line,
		probe_flag => 1,
	    });
	} elsif($line =~ /^probe\s+(\S.*)$/) {
	    # probe existing nodes and variables
	    my $probes = $1;
	    my @names = split /\s*,\s*/, $probes;
	    foreach my $name (@names) {
		my $node_ref = $node_list_ref->lookup_by_name($name);
		$node_ref->set_probe_flag(1) if (defined $node_ref);
		my $variable_ref = $variable_list_ref->lookup_by_name($name);
		$variable_ref->set_probe_flag(1) if (defined $variable_ref);
		if (!defined $node_ref && !defined $variable_ref) {
		    print "ERROR: unknown probe $name\n--> '$line'";
		    exit(1);
		}
	    }
	} else {
	    print "ERROR: unexpected line in the PROBE section (n.b. one probe per line!)\n";
	    print "--> $line\n";
	    exit(1);
	}
    }
}

1;  # don't remove -- req'd for module to return true

