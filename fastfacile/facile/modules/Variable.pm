###############################################################################
# File:     Variable.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Class definition for a biochemical variable.  An ordered list of
#           class instances is created and maintained.
##############################################################################
# Detailed Description:
# ---------------------
#
# Maintains a list of all objects of the class.  If objects are reordered
# index_of attribute is updated appropriately.
#
# Note on functions related to RATE EXPRESSIONS:
#    square()
#    eval_expression()
#  Expressions can be any valid expressions (using MATLAB syntax).
#  When the EasyStoch simulator is used, the
#  expression must be sampled at the appropriate times
#  and the resulting rate passed to the EasyStoch
#  simulator via the stochastic equation file's rate change
#  list (in section IV). To do this, we use perl's eval() function
#  and supply a function mimicking any MATLAB
#  functions that appear in the evaluated expressions.
#
###############################################################################

use strict;
use diagnostics;		# equivalent to -w command-line switch
use warnings;

package Variable;
use Class::Std;
use base qw();
{
    use Carp;
    use POSIX qw(ceil floor);

    use Globals;
    use Utils;
    use Tables;

    #######################################################################################
    # CLASS ATTRIBUTES
    #######################################################################################

    # valid values of the type attribute
    my @types = ("rate", "moiety_total", "constrained_node_expression", "other", "probe");

    #######################################################################################
    # ATTRIBUTES
    #######################################################################################

    my %index_of              :ATTR(get => 'index', init_arg => 'index');
    my %name_of               :ATTR(get => 'name', init_arg => 'name');
    my %value_of              :ATTR(get => 'value', set => 'value', init_arg => 'value');
    my %dimension_of          :ATTR(get => 'dimension', set => 'dimension', init_arg => 'dimension');
    my %type_of               :ATTR(get => 'type', set=> 'type', init_arg => 'type');
    my %is_expression_flag_of :ATTR(get => 'is_expression_flag', init_arg => 'is_expression_flag');  # constant or expression?
    my %source_line_of        :ATTR(get => 'source_line', init_arg => 'source_line');
    my %is_bifurcation_parameter_flag_of :ATTR(get => 'is_bifurcation_parameter_flag', default => 0);

    # attribute determines if user wants this variable to be plotted
    # (support depends on target output)
    my %probe_flag_of                 :ATTR(get => 'probe_flag', set => 'probe_flag', init_arg => 'probe_flag', default => 0);



    #######################################################################################
    # FUNCTIONS
    #######################################################################################
    #--------------------------------------------------------------------------------#
    # mimic MATLAB's square function, which has period 2*pi, range {-1,+1},
    # changes at {0, pi, 2*pi, ...} (for duty cycle of 50%) and has duty cycle
    # as second argument
    # n.b. $pi is not exactly the same as Matlab's pi (one digit less precise)
    # this was to prevent weird floating point effects
    #--------------------------------------------------------------------------------#
    sub square {
	my $t = shift;
	my $duty = shift;
	my ($phase, $phase_mod);
	my $return_val;

	if (!defined $duty) {
	    $duty = 50 ;
	}

	$phase = $t/2.0/$pi;	# unit period

	# we avoid dividing duty cycle by 100
	# to avoid numerical errors due its binary representation
	# for example,  1.25 has exact representation but 0.0125 does not
	my $phase_shift = floor($phase);
	my $rise_time_x100 = 200*$pi*$phase_shift;
	my $fall_time_x100 = 2*$pi*(100*$phase_shift + $duty);

	$return_val = (($t*100.0 >= $rise_time_x100) && ($t*100.0 < $fall_time_x100)) ? 1 : -1;
	#   print "t= $t, duty=$duty square(t)=$return_val phase = $phase, phase_shift=$phase_shift, rise_time=$rise_time fall_time=$fall_time\n";
	return $return_val;
    }

    #######################################################################################
    # CLASS METHODS
    #######################################################################################
    sub get_types {
	my $class = shift;
	return @types;
    }

    #######################################################################################
    # INSTANCE METHODS
    #######################################################################################
    sub BUILD {
        my ($self, $obj_ID, $arg_ref) = @_;

	# check if type is one of defined types, which we defined above
	if ((grep ($_ eq $arg_ref->{type}, @types)) != 1) {
	    print "ERROR: internal code error, unknown type \"".$arg_ref->{type}."\" for variable ".$arg_ref->{name}."\n";
	    exit(1);
	}
    }

#    sub DEMOLISH {
#      !!! if ever we wanted to delete a variable but keep others,
#      !!! we would delete the appropriate element from @variable
#      !!! using splice, then update the indices of elements following
#    }

    sub compare_value {
	my $self = shift;
	my $compare_value = shift;
	my $is_expression_flag = $is_expression_flag_of{ident $self};
	my $value = $value_of{ident $self};
	return ((!$is_expression_flag && $compare_value == $value) ||
		($is_expression_flag && $compare_value eq $value)) ? 1 : 0;
    }

    sub designate_as_bifurcation_parameter {
	my $self = shift;
	$is_bifurcation_parameter_flag_of{ident $self} = 1;
    }

    #--------------------------------------------------------------------------------#
    # Used to evaluate rate expressions in equation file.  Any MATLAB                #
    # functions which may appear in the supplied expression must have a              #
    # corresponding function implemented in perl, e.g. square() function above.
    #--------------------------------------------------------------------------------#
    sub eval_expression {
	my $self = shift;
	my $t = shift;
	my $variable_list_ref = shift;

	my $expression = $self->get_value();

	my @variable_refs = ();
	@variable_refs = $variable_list_ref->get_list() if (defined $variable_list_ref);

	# keep substituting in any variable values into the expression
	# until it becomes static
	my $sub_again_flag = 1;
	my $nesting = 0;
	while ($sub_again_flag && $nesting < 100) {
	    $sub_again_flag = 0;
	    $nesting++;
	    foreach my $var_ref (@variable_refs) {
		my $var_name = $var_ref->get_name();
		my $var_value = $var_ref->get_value();
		if ($expression =~ /(?<!\w)$var_name(?!\w)/) {
		    $sub_again_flag = 1;
		    $expression =~ s/(?<!\w)$var_name(?!\w)/\($var_value\)/g;
		}
	    }
	}
	if ($nesting >= 100) {
	    print "ERROR: detected infinite nesting loop during evaluation of expression\n";
	    print "   --> ".$self->get_value()."\n";
	    exit(1);
	}

	$expression =~ s/(?<!\w)t(?!\w)/\$t/g; # sub in current time
	$expression =~ s/(?<!\w)pi(?!\w)/$pi/g; # sub in pi

	$expression =~ s/\^/\*\*/g; # sub exponentiation operator '^' for '**'

	# now evaluate the expression, which should not have any variables
	my $value = eval("no strict;\n$expression;\nuse strict;");
	if (!is_numeric($value) || $@) {
	    print "ERROR: unable to evaluate expression '$expression' to a numeric value\n";
	    print "  -> $@";
	    exit(1);
	}
	return $value;
    }

    sub eval_rate {
	my $self = shift;
	my $t = shift;
	my $variable_list_ref = shift;

	if ($self->get_is_expression_flag() == 0) {
	    return $self->get_value();
	} else {
	    return $self->eval_expression($t, $variable_list_ref);
	}
    }

    # recursively generate list of variable names in expression
    # (n.b. does not include name of top-lvl variable)
    sub get_dependent_vars {
	my $self = shift;
	my $variable_list_ref = shift;

	my $expression = $self->get_value();

	my @variable_refs = ();
	@variable_refs = $variable_list_ref->get_list() if (defined $variable_list_ref);

	# keep substituting in any variable values into the expression
	# until it becomes static, building list of substituted vars
	my $sub_again_flag = 1;
	my $nesting = 0;
	my %var_names = ();
	while ($sub_again_flag && $nesting < 100) {
	    $sub_again_flag = 0;
	    $nesting++;
	    foreach my $var_ref (@variable_refs) {
		my $var_name = $var_ref->get_name();
		my $var_value = $var_ref->get_value();
		if ($expression =~ /(?<!\w)$var_name(?!\w)/) {
		    $sub_again_flag = 1;
		    $expression =~ s/(?<!\w)$var_name(?!\w)/\($var_value\)/g;
		    $var_names{$var_name} = 1;
		}
	    }
	}
	if ($nesting >= 100) {
	    print "ERROR: detected infinite nesting loop during evaluation of expression\n";
	    print "   --> ".$self->get_value()."\n";
	    exit(1);
	}
	return sort keys %var_names;
    }
}

# TESTING
sub run_testcases {
    print "Testing class: Variable\n";
    
    print "Creating var1 object: ";
    my $var1_ref = Variable->new({
       name => "f1",
       index => 0,
       value => 1.0,
       type => "rate",
       dimension => 2,
       is_expression_flag => 0,
       source_line => "f1=1.0",
      });
    print $var1_ref->_DUMP();
    print "Done testing class: Variable\n";

    # testing of eval_expression() and square()
    print "\nTesting square() and eval_expression():\n";
    my ($t, $f, $valid_f);

    $var1_ref->set_value("0.5*(square(2*pi*t,30)+1)"); 
    $t=10.3; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);

    $var1_ref->set_value("0.5*(square(2.0*pi*(t-10.0)/40.0, 1.25)+1)");

    $t=-45; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=9.99; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=10; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 1; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=10.499; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 1; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=10.5; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=10.51; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);

    $t=49.99; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=50; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 1; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=50.499; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 1; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=50.5; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=50.51; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);

    $t=169.99; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=170; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 1; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=170.499; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 1; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=170.5; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    $t=170.51; $f=$var1_ref->eval_expression($t); print "t=$t, f(t)=".$f."\n";
    $valid_f = 0; print "ERROR: f(t) should be $valid_f not $f\n" if ($f != $valid_f);
    print "Done resting square() and eval_expression().\n";

}

# Package BEGIN must return true value
return 1;


