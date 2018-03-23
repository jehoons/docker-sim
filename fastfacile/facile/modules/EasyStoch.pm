###############################################################################
# File:     EasyStoch.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Export files in EasyStoch's simulation input file format.
###############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

package EasyStoch;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
		AssignID
		export_easystoch_input_file
		export_easystoch_reactions
		export_easystoch_converter_file
	   );


use POSIX qw(ceil floor);

use Globals;
use Utils;
use Tables;

#######################################################################################
# FUNCTIONS
#######################################################################################

sub vector {
  my ($start, $interval, $end) = @_;

  # compute vector and return
  my $num_points = floor(($end - $start) / $interval);
  return [map {$start + $_ * $interval} (0..floor($num_points))];
}

#######################################################################################
# INSTANCE METHODS
#######################################################################################

#-------------------------------------------------------#
# Assigns ID numbers to nodes.  The ordering is         #
# special due to the requirements of the stochastic     #
# simulation input file.  Each promoter is listed first #
# immediately followed by associated complex nodes,     #
# and finally all remaining non promoter/complex        #
# nodes.                                                #
#-------------------------------------------------------#
sub AssignID {
    my $self = shift;

    my $node_list_ref = $self->get_node_list();

    # First assign IDs to promoters and their associated complexes
    # (this ordering is required by stochastic equation file)
    my $ID = 0;
    foreach my $promoter_ref ($node_list_ref->get_promoters()) {
	$promoter_ref->set_ID($ID++);
	foreach my $complex_ref ($promoter_ref->get_associated_complexes()) {
	    $complex_ref->set_ID($ID++);
	}
    }
    # Next assign IDs to remaining nodes
    foreach my $node_ref (grep(!$_->is_promoter() && !$_->is_complex(), $node_list_ref->get_list())) {
	$node_ref->set_ID($ID++);
    }
}

#---------------------------------------------------#
# Prints the stochastic simulation input file.      #
#---------------------------------------------------#
sub export_easystoch_input_file {
    my $self = shift;

    my $reaction_list_ref = $self->get_reaction_list();
    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $config_ref = $self->get_config_ref();
    my $compartment_volume = $config_ref->{compartment_volume};
    my $tf = $config_ref->{tf};

    # assign IDs to nodes
    $self->AssignID();

    my $totalPromoters;
    my $totalSpecies;
    my $totalReactions;
    my $print;
    my $i = 0;
    my $j = 0;

    #--------------------------------------------------------------------------------
    #-- Section I -- list of substrates and their concentrations
    #--------------------------------------------------------------------------------
    #column 1:  initial value
    #column 2:  name of substrate
    #column 3:  associated promoter ID if complex, -1 otherwise
    #column 4:  replication time if promoter, 9999 otherwise
    #column 5:  reactantID
    $print .= "# Section I (substrates): iv, name, associated promoter (if complex), time (for promoter), EasyStoch ID\n";

    #loop through nodes sorted by ID number
    my @nodes = $node_list_ref->get_list();
    my @ID_sorted_nodes = sort {$a->get_ID() <=> $b->get_ID()} @nodes;
    foreach my $node_ref (@ID_sorted_nodes) {
	my $ID = $node_ref->get_ID();
	my $node_name = $node_ref->get_name();
	my $initial_value = $node_ref->get_initial_value_in_molecules($compartment_volume);
	my ($associated_promoter, $associated_promoter_ref, $associated_promoter_ID);
	$associated_promoter = $node_ref->get_associated_promoter();
	if (defined $associated_promoter) {
	    $associated_promoter_ref = $node_list_ref->lookup_by_name($associated_promoter);
	    $associated_promoter_ID = $associated_promoter_ref->get_ID();
	} elsif ($node_ref->is_promoter()) {
	    $associated_promoter_ID = $ID;  # if promoter, stoch expects ass. ID to be promoter ID
	}
	my $replication_time = $node_ref->get_replication_time();
	$print .= "$initial_value\t";  #column1
	$print .= "$node_name\t"; #column2
	$print .= ($node_ref->is_complex() || $node_ref->is_promoter() ?
		   "$associated_promoter_ID\t" : "-1\t"); # column3
	$print .= ($node_ref->is_promoter() ? "$replication_time\t" : "9999\t");  # column4
	$print .= "$ID\t\n";  #column5
    }

    $totalPromoters = $node_list_ref->get_promoters();
    $totalSpecies = $node_list_ref->get_count();

    # end of first section printed

    #--------------------------------------------------------------------------------
    #-- Section II:  list of (forward) reactions and (forward) rates
    #--------------------------------------------------------------------------------
    #column 1:  reactantID for first reactant  (reactantIDs stored in %idHash)
    #column 2:  reactantID for second reactant
    #column 3:  reactantID for first product
    #column 4:  reactantID for second product
    #column 5:  reactantID for third product
    #column 6:  rate for reaction
    #column 7:  reactionID
    $print .= "# Section II (reactions): ID 1st reactant, 2nd reactant, 1st product, 2nd product, 3rd product, reaction rate, reaction ID\n";
    $print .= $self->export_easystoch_reactions();

    $totalReactions = $reaction_list_ref->get_count();

    #--------------------------------------------------------------------------------
    #--- Section III -- dependency matrix
    #--------------------------------------------------------------------------------
    # this is reaction dependency matrix giving the reactions that will change 
    # their probability of occurring if given reaction occurs
    # list the reaction ID's (i.e. the index) affected on each line, end each line with "P"
    $print .= "# Section III (dependency matrix): list ID of affected reactions\n";
    # call class method to compute the dependencies between reactions
    $reaction_list_ref->update_dependency_lists($node_list_ref);
    foreach my $reaction_ref ($reaction_list_ref->get_list()) {
	# print out all the reactionID's affected by (and excluding) the current reaction
	my $reaction_index = $reaction_ref->get_index();
	foreach my $dependent_reaction_ref ($reaction_ref->get_dependency_list()) {
	    my $dependent_reaction_ID = $dependent_reaction_ref->get_index();
	    $print .= "$dependent_reaction_ID\t";
	}
	$print .= "P\n";
    }

    #--------------------------------------------------------------------------------
    # --- Section IV -- Sample dynamic rate parameters
    #--------------------------------------------------------------------------------
    $print .= "# Section IV (dynamic rates/species change): reaction/species index, time of rate change, new value\n";

    # print message indicating which are the piecewise-linear rates
    my @first_order_dynrate_reaction_list = grep {$_->get_easystoch_dynrate_order() == 1} $reaction_list_ref->get_list();
    if (@first_order_dynrate_reaction_list) {
	$print .= "# N.b. the following reactions have piecewise-linear rates according\n";
	$print .= "# to the equation file (c.f. EasyStoch's --rate_vary switch):\n";
	$print .= "#   --> ".join(",", map {$_->get_index()} @first_order_dynrate_reaction_list)."\n";
    }

    my $easystoch_sample_times_ref = $config_ref->{easystoch_sample_times};
    my %easystoch_sample_times = %{$easystoch_sample_times_ref};
    
    if (%easystoch_sample_times) {
	foreach my $rate (keys %easystoch_sample_times) {
	    $print .= "# Dynamic rate sample times for $rate: $easystoch_sample_times{$rate}\n";
	}

	my @rate_changes = ();
	foreach my $reaction_ref ($reaction_list_ref->get_list()) {
	    my @rate_vars = $reaction_ref->get_rate_ref()->get_dependent_vars($variable_list_ref);
	    unshift @rate_vars, $reaction_ref->get_rate_ref()->get_name();
	    my @sample_times = ();
	    # get set of sample times for this reaction
	    foreach my $rate_var (@rate_vars) {
		if (defined $easystoch_sample_times{$rate_var}) {
		    my $sample_times_string = $easystoch_sample_times{$rate_var};
		    if ($sample_times_string =~ /table\(.*\)$/) {
			my $sample_times_ref;
			eval("no strict; \$sample_times_ref = $sample_times_string; use strict;");
			if ($@) {
			    print "ERROR: unable to evaluate $sample_times_string \n";
			    print "  -> $@";
			    exit(1);
			}
			push @sample_times, @$sample_times_ref;
		    } elsif ($sample_times_string =~ /vector\(.*\)$/) {
			# special case: if end time is tf, substitute final time
			$sample_times_string =~ s/tf\s*\)/\$tf\)/;

			my $sample_times_ref;
			eval("no strict; \$sample_times_ref = $sample_times_string; use strict;");
			push @sample_times, @$sample_times_ref;
		    } else {
			push @sample_times, split(/\s*[, ]\s*/,$sample_times_string);
		    }
		}
	    }
	    # sort and remove duplicate times
	    @sample_times = sort {$a <=> $b} @sample_times;
	    my @non_dups = grep {($_ == $#sample_times) ||
				 $sample_times[$_] != $sample_times[$_+1]} (0..($#sample_times));
	    @sample_times = map {$sample_times[$_]} @non_dups;

	    # At each sample time check if associated rate is an expression,
	    # if so evaluate new value, and store only if it changed.
	    my $rate_ref = $reaction_ref->get_rate_ref();
	    my $rate_name = $rate_ref->get_name();
	    my $rate_value = $rate_ref->get_value();
	    my $reaction_ID = $reaction_ref->get_index();
	    my $current_rate = $rate_ref->eval_rate(0, $variable_list_ref);

	    foreach my $sample_time (@sample_times) {
		next if $sample_time == 0; # skip t=0
		my $new_rate = $rate_ref->eval_rate($sample_time, $variable_list_ref);
		#print "XXX: t=$sample_time, $rate_value, $current_rate -> $new_rate\n";
		if ($new_rate != $current_rate) {
		    push @rate_changes, [$sample_time, sprintf("%-8d %20le %20le   # $rate_name = $rate_value",
							       $reaction_ID, $sample_time,
							       $new_rate)];
		    $current_rate = $new_rate;
		}
	    }
	}

	# now order rate changes according to time and print
	@rate_changes = sort {$a->[0] <=> $b->[0]} @rate_changes;
	$print .= join("\n", map {$_->[1]} @rate_changes) ."\n";
    } else {
	$print .= "# (no sample times given)\n" if (!%easystoch_sample_times);
    }

    #finally, we need to include a little header:
    my $header = $totalReactions . " " . $totalSpecies . " " . $totalPromoters ."\n";
    $print = "# Section 0 (header): no. reactions, no. species, no. promoters\n". $header . $print;
    return $print;
}

#---------------------------------------------------#
# Prints a line of section II of the stochastic     #
# simulation input file.                            #
#---------------------------------------------------#
sub export_easystoch_reactions {
    my $self = shift;

    my $config_ref = $self->get_config_ref();
    my $biRateThreshold = $config_ref->{biRateThreshold};

    my $reaction_list_ref = $self->get_reaction_list();
    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $print;
    
    foreach my $reaction_ref ($reaction_list_ref->get_list()) {

	my $reactionID = $reaction_ref->get_index();

	# check number of substrates
	if (@{$reaction_ref->get_substrate_names_ref()} > 2) {
	    print "ERROR:  Cannot have more than 2 substrates for stochastic input.\n";
	    exit(1);
	}
	# print IDs of substrates
	foreach my $substrate_name (@{$reaction_ref->get_substrate_names_ref()}) {
	    my $substrate_ID = $node_list_ref->lookup_by_name($substrate_name)->get_ID();
	    $print .= "$substrate_ID\t";
	}
	# check that rates for bimolecular reactions are in the correct units
	# (even though it is a stochastic sim, bimolecular rate is still given in M^-1s^-1)
	# !!! ??? is this warning best printed when parsing or defining the variable ???
	# (same mistake could be made for other simulators!!!)
	if (!$quiet && ($reaction_ref->get_rate_ref()->get_dimension() == 2)) {
	    my $value = $reaction_ref->get_rate_ref()->eval_rate(0, $variable_list_ref);
	    if ($value < $biRateThreshold) {
		print "Warning: Low initial (t=0) bimolecular reaction rate ".$reaction_ref->get_rate_ref()->get_name()."=$value\n";
		print "         --> in reaction: ".$reaction_ref->get_source_line()."\n";
		print "Warning: (bimolecular interactions should be in units of inverse molar inverse time)\n";
	    }
	}
	# print -1 when number of substrates smaller than 2
	for (my $k = 0; $k < 2 - (@{$reaction_ref->get_substrate_names_ref()}); $k++) {
	    $print .= "-1\t";  
	}

	# check number of products
	if (@{$reaction_ref->get_product_names_ref()} > 3) {
	    print "ERROR:  Cannot have more than 3 products for stochastic input.\n";
	    exit(1);
	}
	# print IDs of products
	foreach my $product_name (@{$reaction_ref->get_product_names_ref()}) {
	    my $product_ID = $node_list_ref->lookup_by_name($product_name)->get_ID();
	    $print .= "$product_ID\t";
	}
	# print -1 when number of products smaller than 3
	for (my $k = 0; $k < 3 - (@{$reaction_ref->get_product_names_ref()}); $k++) {
	    $print .= "-1\t";	#print -1 if no additional products
	}

	# print reaction rates, evaluating expression if appropriate
	my $rate_ref = $reaction_ref->get_rate_ref();
	$print .= $rate_ref->eval_rate(0, $variable_list_ref);

	# print reaction index
	$print .= "\t$reactionID";

	# print a comment giving reaction details
	$print .= " # " . join(" + ", @{$reaction_ref->get_substrate_names_ref()})." -> " .
	join(" + ", @{$reaction_ref->get_product_names_ref()}).";";
	$print .= " ".$reaction_ref->get_rate_ref()->get_name()."=".$reaction_ref->get_rate_ref()->get_value()."\n";

    }

    return $print;
}

#---------------------------------------------------#
# Prints the simdata Matlab converter script.       #
#---------------------------------------------------#
sub export_easystoch_converter_file {
    my $self = shift;

    my $print;

    my $node_list_ref = $self->get_node_list();

    my @node_names = $node_list_ref->get_names();

    #********************************************************************#
    # $print returns Matlab script that converts simdata to variables   #         
    #********************************************************************#

    $print .= "% converts simulation output\n% assumes simulation time series data is in simdata variable\n\n";

    # first column of simdata (starting from index of 1) is time
    $print .= "t= simdata(:,1);\n";

    # the following 2*n columns (starting from index of 2) are node counts and concentrations
    # extract node count values from simdata
    for (my $i=0; $i < @node_names; $i++) {
	$print .= "$node_names[$i]= simdata(:,".($i+2).");\n";
    }
    # extract node concentration values from simdata
    $print .= "\n% concentrations\n"; 
    $print .= "if size(simdata,2) > ".(@node_names+1)."\n";
    for (my $i=0; $i < @node_names; $i++) {
	$print .= "    ".$node_names[$i]."conc= simdata(:,".(@node_names+$i+2).");\n";
    }

    $print .= "end;\n\n";
    return $print;
}


1;  # don't remove -- req'd for module to return true

