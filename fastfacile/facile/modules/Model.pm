######################################################################################
# File:     Model.pm
# Author:   Julien F. Ollivier
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Container for all model information.
#
######################################################################################
# Detailed Description:
# ---------------------
#
#
######################################################################################

use strict;
use diagnostics;		# equivalent to -w command-line switch
use warnings;

package Model;
use Class::Std;
use base qw();
{
    use Carp;
    use Utils;

    use NodeList;
    use ReactionList;
    use VariableList;

    # import Model class methods from these packages
    use Parser;
    use Matlab;
    use EasyStoch;
    use Mathematica;
    use Maple;
    use Moiety;
    use AUTO;
    use XPP;
    use SBML;

    #######################################################################################
    # CLASS ATTRIBUTES
    #######################################################################################

    #######################################################################################
    # ATTRIBUTES
    #######################################################################################
    my %node_list_of :ATTR(get => 'node_list');
    my %reaction_list_of :ATTR(get => 'reaction_list');
    my %variable_list_of :ATTR(get => 'variable_list');

    my %config_ref_of :ATTR(get => 'config_ref', set => 'config_ref');

    my %input_file_name_of :ATTR(get => 'input_file_name', set => 'input_file_name');
    my %file_buffer_ref_of :ATTR(get => 'file_buffer_ref', set => 'file_buffer_ref');

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

	$node_list_of{$obj_ID} = NodeList->new();
	$reaction_list_of{$obj_ID} = ReactionList->new();
	$variable_list_of{$obj_ID} = VariableList->new();

	# INITIALIZE CONFIGURATION
	my $config_ref = $config_ref_of{$obj_ID} = {};

	# General
	# -------
	# final integration time for Matlab ODE & EasyStoch sims
	$config_ref->{tf}="NO_TIME_SPECIFIED";
	# volume of simulation compartment
	$config_ref->{compartment_volume} = "NOT_SPECIFIED";

	# Matlab specific
	# ---------------
	# string giving list of sampling times of ODE state vector
	$config_ref->{tv}="[t0 tf]";
	# dydt function passed to ode solver will output progress ticks
	$config_ref->{tk} = -1;
	# matlab ode solver to use
	$config_ref->{solver} = "ode23s";
	# matlab options to set using odeset
	$config_ref->{solver_options} = "odeset()";
	# (ode_event.m) list of times where rate params change discontinuously
	$config_ref->{ode_event_times} = undef;
	# timescale of N+1 integration intervals for steady-state check
	$config_ref->{SS_timescale} = "";
	# tolerance for steady-state check in each integration interval
	$config_ref->{SS_RelTol} = "";
	$config_ref->{SS_AbsTol} = "";
	# flag indicating that probes should be plotted in Matlab
	$config_ref->{plot_flag} = 0;

	# EasyStoch specific
	# ------------------
	# Threshold concentration for low bimol. rate constant warning
	$config_ref->{biRateThreshold} = 1.0e4;
	# (EasyStoch) per-rate lists of times where rate params should be sampled
	$config_ref->{easystoch_sample_times} = {};

	# XPP specific
	# ------------
	# xpp configuration commands @[...]
	$config_ref->{xpp_config} = [];
    }

    #--------------------------------------------------------------------------------------
    # Function: xxx
    # Synopsys: 
    #--------------------------------------------------------------------------------------
    sub xxx {
	my $self = shift;
    }

}


sub run_testcases {

    my $model_ref = Model->new({});

    print $model_ref->_DUMP();

    print $model_ref->export_mathematica_file();

}


# Package BEGIN must return true value
return 1;

