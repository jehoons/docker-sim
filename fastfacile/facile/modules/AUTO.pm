###############################################################################
# File:     AUTO.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Export files required for analysis with AUTO program.
##############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

package AUTO;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

# these subroutines are imported when you use AUTO.pm
@EXPORT = qw(
	     export_AUTO_file
	     export_AUTO_file_sections
	   );


#######################################################################################
# FUNCTIONS
#######################################################################################
#------------------------------#
# Read steady state from file  #
#------------------------------#
sub read_steady_state {
    my $inputData=shift;
    open(DATA, $inputData) or die "Can't open $inputData\n";
    my @lines=<DATA>;
    $lines[$#lines] =~ s/^\s*//;
    my @data=split(/\s+/,$lines[$#lines]);
    close DATA;
    return @data;
}

#-------------------------------------------------#
# subroutine to parse x^y into pow(x,y)           #
# called from export_AUTO_file to comply with C #
#-------------------------------------------------#
# Synopsys: transforms powers of the form a^b into C code pow(a,b)
# Detailed Description:
# Matlab and other languages require powers in the form a^b while C/C++ would
# write powers as a^b.  This script transforms the former syntax into the latter.
# It should deal with nested expressions such as a^b^c or a^(b^c).  
# Functions should be respected so f*(a)^c becomes f*pow((a),c) while the expression
# f(a)^c becomes pow(f(a),b).
# Note: this script assumes the common right-to-left precedence rule:
#  a^b^c = a^(b^c) = pow(a,pow(b,c)).  However, matlab does not follow this rule.  As an 
# example note that 2^1^2 = 4 in matlab while 2^1^2 = 2 folowing the right-to-left rule.
# Usage:
# mat2pow.pl "mathematical expression"
# Example:
# mat2pow.pl "a^b^c"
sub mat2pow {
  my $c=shift(@_);
  my @letrs;
  my $parenthMatch;
  while ($c =~ m/(.*)\^(.*?)$/){
    my $baseWhl=$1;
    my $expWhl=$2;
    ## manipulate right-most power

    ## base
    my $base="";
    if($baseWhl=~m/\)$/){ # if base begins with parenthesis
      @letrs=split(//,$baseWhl);@letrs=reverse(@letrs);
      $parenthMatch=0;my $k=0;
      do {
	if ($letrs[$k] eq ")"){$parenthMatch=$parenthMatch-1;}
	if ($letrs[$k] eq "("){$parenthMatch=$parenthMatch+1;}
	$k++
      } while ($parenthMatch!=0 && $k<@letrs);
      while(exists($letrs[$k]) &&  ($letrs[$k]  =~ m/\w{1}/)){#include fncts,eg,sin(a)
	$k++;
      }
      $base=substr($baseWhl,length($baseWhl)-$k);
    } else { # if base does not begin with parenthesis
      my @terms=split(/\+|\-|\*|\/|\^|\(/,$baseWhl);
      if (@terms!=0){$base=$terms[@terms-1]} else {$base=$baseWhl};
    }
    substr($baseWhl,length($baseWhl)-length($base)) = "pow($base,)";

    ## exponent
    my $exp="";
    @letrs=split(//,$expWhl);
    $parenthMatch=0;my $k=0;
    ### include fncts,eg,sin(a) and also decimal notation as 1.2
    while($k<@letrs && $letrs[$k]  =~ m/\w{1}|\.{1}/){$k++;}
    ### end include
    if($k<@letrs && $letrs[$k] =~ m/\(/){ # if parenthesis
      do {
	if ($letrs[$k] eq "("){$parenthMatch=$parenthMatch-1;}
	if ($letrs[$k] eq ")"){$parenthMatch=$parenthMatch+1;}
	$k++
      } while ($parenthMatch!=0 && $k<@letrs);
    }
    $exp=substr($expWhl,0,$k);
    substr($expWhl,0,length($exp)) = "";
    $baseWhl =~ s/\,\)/\,$exp\)/; #modify base to include exponent within "pow"
    $c=$baseWhl.$expWhl;# re-construct string.
  }
  return $c;
}

#######################################################################################
# INSTANCE METHODS
#######################################################################################
sub export_AUTO_file {
    my $self = shift;
    my $steady_state_file = shift;

    my @steady_state;
    if ($steady_state_file){
	@steady_state = read_steady_state($steady_state_file);
    } else {
	@steady_state = ();
    }

    my $config_ref = $self->get_config_ref();
    my $compartment_volume = $config_ref->{compartment_volume};

    my ($C_var_computations, $C_var_initialisation,
	$C_var_declarations) = $self->export_AUTO_file_sections(
	    \@steady_state,
	   );

    my $toPrint;

    $toPrint .= "
#include \"auto_f2c.h\"
/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
/*   ab :            The A --> B reaction */
/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
int func (integer ndim, const doublereal *u, const integer *icp,
          const doublereal *par, integer ijac,
          doublereal *f, doublereal *dfdu, doublereal *dfdp) {
";
    $toPrint .= "doublereal $C_var_declarations";
    $toPrint .= "
  /* Evaluates the algebraic equations or ODE right hand side */

  /* Input arguments : */
  /*      ndim   :   Dimension of the ODE system */
  /*      u      :   State variables */
  /*      icp    :   Array indicating the free parameter(s) */
  /*      par    :   Equation parameters */

  /* Values to be returned : */
  /*      f      :   ODE right hand side values */

  /* Normally unused Jacobian arguments : IJAC, DFDU, DFDP (see manual) */

";

    $toPrint .= "$C_var_computations";
    $toPrint .= "
return 0;
}
/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
int stpnt (integer ndim, doublereal t,
           doublereal *u, doublereal *par) {
  /* Input arguments : */
  /*      ndim   :   Dimension of the ODE system */

  /* Values to be returned : */
  /*      u      :   A starting solution vector */
  /*      par    :   The corresponding equation-parameter values */


  /* Initialize the equation parameters */

";
    $toPrint .= "$C_var_initialisation";
    $toPrint .= "
 return 0;
}
/* The following subroutines are not used here, */
/* but they must be supplied as dummy routines */

/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
int bcnd (integer ndim, const doublereal *par, const integer *icp,
          integer nbc, const doublereal *u0, const doublereal *u1, integer ijac,
          doublereal *fb, doublereal *dbc) {
  return 0;
}
/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
int icnd (integer ndim, const doublereal *par, const integer *icp,
          integer nint, const doublereal *u, const doublereal *uold,
          const doublereal *udot, const doublereal *upold, integer ijac,
          doublereal *fi, doublereal *dint) {
    return 0;
}
/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
int fopt (integer ndim, const doublereal *u, const integer *icp,
          const doublereal *par, integer ijac,
          doublereal *fs, doublereal *dfdu, doublereal *dfdp) {
    return 0;
}
/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
int pvls (integer ndim, const doublereal *u,
          doublereal *par) {
    return 0;
}
/* ---------------------------------------------------------------------- */
/* ---------------------------------------------------------------------- */
";

    return $toPrint;
}

#---------------------------------------------------#
# Prints the input files required for AUTO          #
#---------------------------------------------------#
sub export_AUTO_file_sections {
    my $self = shift;
    my $steady_state_ref = shift;

    my @steady_state= @$steady_state_ref;

    my $config_ref = $self->get_config_ref();
    my $compartment_volume = $config_ref->{compartment_volume};

    my $reaction_list_ref = $self->get_reaction_list();
    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my ($C_var_computations,$C_var_initialization,$C_var_declarations);  # returns ode definition

    ## define species
    ## TO DO: make sure all number have decimal representation (need a comma)
    ## may be worth doing this at the time of storing the variables
    ## instead of now.
    my @free_nodes = $node_list_ref->get_ordered_free_node_list();
    $C_var_computations .= "/* free species */\n";
    $C_var_initialization .= "/* free species */\n";
    for(my $j = 0; $j < @free_nodes; $j++){
	my $node_name = $free_nodes[$j]->get_name();
	my $initial_value;
	if (@steady_state){
	    $initial_value=$steady_state[$j+1];
	} else {
 	    $initial_value = $free_nodes[$j]->get_initial_value_in_molarity($compartment_volume);
	}
	$C_var_declarations .= "$node_name,";
	$C_var_initialization .= sprintf("%-20s /* $node_name */\n", "u[$j] = (doublereal) $initial_value;");
	$C_var_computations .= "$node_name = u[$j];\n";
    }

    # !!! don't need this anymore ???
    #----------------------------------------------------------------------#
    # re-order the variable list so each expression is a function of       #
    # previously defined variables                                         #
    #----------------------------------------------------------------------#
    #  $variable-list_ref->reorder_variable_list();

    ## if no bifurcation parameter specified, define all that are not verbatim
    my @bifurcation_parameters = grep ($_->get_is_bifurcation_parameter_flag() == 1,
				       $variable_list_ref->get_list());
    if(@bifurcation_parameters == 0){
	print "Warning: No bifurcation parameter specified in BIFURC_PARAM.\n";
	print "Warning: Defining all non-verbatim rates/moieties as bifurcation parameters.\n";
	print "Warning: AUTO may not like this...\n\n";
	@bifurcation_parameters = grep (($_->get_type eq "rate" || 
					 $_->get_type eq "moiety_total") &&
					 $_->get_is_expression_flag() == 0,
					$variable_list_ref->get_list());
	foreach my $bifurcation_parameter_ref (@bifurcation_parameters) {
	    $bifurcation_parameter_ref->designate_as_bifurcation_parameter();
	}
    }

    ## specify what to print
    my $j = 0;
    my @variables = $variable_list_ref->get_list();
    my @constant_rate_params = grep (($_->get_type() =~ /^(rate)|(other)$/ &&
				      $_->get_is_expression_flag() == 0), @variables);
    my @moiety_totals = grep ($_->get_type() eq "moiety_total", @variables);
    my @constrained_node_expressions = grep ($_->get_type() eq "constrained_node_expression",
					     @variables);
    my @rate_expressions = grep ($_->get_type() =~ /^(rate)|(other)$/ &&
				 $_->get_is_expression_flag() == 1, @variables);

    # bifurcation parameters need their own index in the C code
    my $bifurcation_parameter_index = 0;

    # ordinary rate constants, e.g. binary forward rate of kf1=1e6 (M^-1 s^-1)
    $C_var_computations .= "\n/* constants */\n";
    $C_var_initialization .= "\n/* constants */\n";
    for (my $i=0; $i < @constant_rate_params; $i++) {
	my $variable_ref = $constant_rate_params[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$C_var_declarations .= "$variable_name,";
	if($variable_ref->get_is_bifurcation_parameter_flag() == 1) {
	    $C_var_computations .= "$variable_name=par[$bifurcation_parameter_index];\n";
	    $C_var_initialization .= sprintf("%-20s /* $variable_name */\n", "par[$bifurcation_parameter_index]=$variable_value;");
	    $bifurcation_parameter_index++;
	} else {
	    $C_var_computations .= "$variable_name=(doublereal)$variable_value;\n";
	}
    }

    # moiety totals, e.g. E_moiety = 123 (mol/L)
    $C_var_computations .= "\n/* moiety totals */\n";
    $C_var_initialization .= "\n/* moiety totals */\n";
    for (my $i=0; $i < @moiety_totals; $i++) {
	my $variable_ref = $moiety_totals[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$C_var_declarations .= "$variable_name,";
	if($variable_ref->get_is_bifurcation_parameter_flag() == 1) {
	    $C_var_computations .= "$variable_name=par[$bifurcation_parameter_index];\n";
	    $C_var_initialization .= sprintf("%-20s /* $variable_name */\n", "par[$bifurcation_parameter_index]=$variable_value;");
	    $bifurcation_parameter_index++;
	} else {
	    $C_var_computations .= "$variable_name= $variable_value;\n";
	}
    }

    # contrained node expressions, e.g. E = C - E_moiety
    $C_var_computations .= "\n/* dependent species */\n";
    for (my $i=0; $i < @constrained_node_expressions; $i++) {
	my $variable_ref = $constrained_node_expressions[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();

	if($variable_ref->get_is_bifurcation_parameter_flag() == 1) {
	    print "ERROR: internal error, don't know what to do with a constrained node expression ".
	    "that is designated as a bifurcation parameter\n";
	    exit(1);
	}

	$C_var_declarations .= "$variable_name,";
	$C_var_computations .= "$variable_name= $variable_value;\n";
    }

    # rate expressions
    $C_var_computations .= "\n/* expressions */\n";
    for (my $i=0; $i < @rate_expressions; $i++) {
	my $variable_ref = $rate_expressions[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();

	$C_var_declarations .= "$variable_name,";

	if($variable_ref->get_is_bifurcation_parameter_flag() == 1) {
	    print "ERROR: internal error, don't know what to do with a rate expression ".
	    "that is designated as a bifurcation parameter\n";
	    exit(1);
	}

	my $expression = $variable_value;
	# substitute a^b for pow(a,b)
	if ($expression =~ m/\^/){$expression=mat2pow($expression);};
	# end substitute
	$C_var_computations .= "$variable_name= $expression;\n";
    }

    # replace trailing "," with ";"
    $C_var_declarations =~ s/,$/\;/;

    # print out differential equations for the free nodes
    $C_var_computations .= "\n/* ode for independent species */\n";
    for(my $j = 0; $j < @free_nodes; $j++){
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

	my $ode_string;
	if (defined $ode_rhs) {
	    $ode_string = "f[$j] = $ode_rhs";
	} else {
	    $ode_string = "f[$j] = 0";
	}
	$C_var_computations .= sprintf("%-40s;   /* d/dt ($node_name) */\n", $ode_string);
    }

    # !!! what to do here -- print initial values for free nodes only ???
    ## print initial values 
    ## TO DO: integers may need a decimal representation.
    #for(my $j = 0; $j < @nodeList; $j++){
    #  $C_var_initialization .= "$nodeList[$j]=(doublereal)$nodeHash{$nodeList[$j]}{iValue};\n";
    #}
    return ($C_var_computations, $C_var_initialization, $C_var_declarations);
}

1;  # don't remove -- req'd for module to return true

