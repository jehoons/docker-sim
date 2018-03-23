#####################################################################################
# File:     Makefile
#
# Copyright (C) 2005-2012 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Makefile for Facile application
#
#####################################################################################

do_nothing:
	@echo "To make a tarball, try 'make tarball'"
	@echo "To run all testcases, try 'make test'"

RELEASE = RELEASE_0V41
RELEASE_FILES = Makefile *.TXT ode_event.m *.pl modules/*.pm test/modules/*.log test/examples/*/*.eqn test/examples/*/*Script.m
TARBALL_DIR = facile_$(RELEASE)

tarball:
	mkdir -p $(TARBALL_DIR)
	cp --parents -p $(RELEASE_FILES) $(TARBALL_DIR)
	rm -f $(TARBALL_DIR).tar.gz
	tar -czf $(TARBALL_DIR).tar.gz $(TARBALL_DIR)
	rm -rf $(TARBALL_DIR)

group = swainlab

read_permissions :
	chmod 770 `pwd`
	find . -type 'd' | xargs chmod 770
	find . -name 'Makefile' | xargs chmod 440
	find . -name '*.TXT' | xargs chmod 440
	find . -name '*.pl' | xargs chmod 550
	find . -name '*.pm' | xargs chmod 440
	find . -name '*.eqn' | xargs chmod 440
	find . -name '*.m'   | xargs chmod 440
	find . -name '*.ma'  | xargs chmod 440
	find . -name '*.c'   | xargs chmod 440
	find . -name '*.log' | xargs chmod 440
	chgrp -R $(group) .

write_permissions :
	chmod 770 `pwd`
	find . -type 'd' | xargs chmod 770
	find . -name 'Makefile' | xargs chmod 640
	find . -name '*.TXT' | xargs chmod 640
	find . -name '*.pl' | xargs chmod 750
	find . -name '*.pm' | xargs chmod 640
	find . -name '*.eqn' | xargs chmod 640
	find . -name '*.m'   | xargs chmod 640
	find . -name '*.ma'  | xargs chmod 640
	find . -name '*.c'   | xargs chmod 640
	find . -name '*.log' | xargs chmod 640
	chgrp -R $(group) .

module_tests = \
	test/modules/Node.log \
	test/modules/NodeList.log \
	test/modules/Variable.log \
	test/modules/VariableList.log \
	test/modules/Reaction.log \
	test/modules/ReactionList.log \
	test/modules/Model.log \

general_tests = \
	test/examples/testMatlab/testMatlab.log \
	test/examples/testStoch/GTPase.log \
	test/examples/testStoch/DynRates.log \
	test/examples/repression/repression.log \
	test/examples/michaelis_menten/michaelis_menten.log \
	test/examples/poisson/poisson.log \
	test/examples/config/config.log \
	test/examples/steady_state/steady_state.log \
	test/examples/steady_state/G437_I00.log \
	test/examples/steady_state/G437_I43.log \
	test/examples/sbml/michaelis_menten.log

auto_tests = \
	test/examples/cornish/cornish.log \
	test/examples/dimerization/dimerization.log \
	test/examples/Markevich/Markevich.log \
	test/examples/loop_and_chain/loop_and_chain.log \
	test/examples/moiety_repeated_velocity/moiety_repeated_velocity.log \
	test/examples/PKC/PKC.log \


test: test_modules test_general test_auto

test_modules : $(module_tests)

test_general : $(general_tests)

test_auto : $(auto_tests)

#-------------------------------------------------------------------------------------
# MODULE TESTS
#-------------------------------------------------------------------------------------
test/modules/%.log : FORCE
	@echo "Running $* testcase..."
	-rm -f test/modules/$*.log
	-perl -Imodules -M$* -e '$*::run_testcases()' 2>&1 | tee -a test/modules/$*.log
	-bzr diff $@

#-------------------------------------------------------------------------------------
# GENERAL FUNCTIONALITY TESTS
#-------------------------------------------------------------------------------------

test/examples/testMatlab/testMatlab.log : FORCE
	cd $(@D); rm -f testMatlab.log testMatlabScript.log testMatlabDriver.m testMatlab_odes.m testMatlab_r.m testMatlab_s.m testMatlab.ma
	./facile.pl -M -P -m -t 5.0 -k 1.0 -v "[t0 tf]" -o $(@D)/testMatlab $(@D)/testMatlab.eqn 2>&1 | tee -a $(@D)/testMatlab.log
	@echo "***********************************************************************************************"
	@echo "PLEASE VIEW MATLAB RESULTS, THEN TYPE EXIT AND INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	cd $(@D); matlab -nodesktop -nosplash -logfile testMatlabScript.log -r testMatlabScript 2>&1 | tee -a testMatlab.log
	-bzr diff $(@D)/testMatlab.log
	-bzr diff $(@D)/testMatlabScript.log
	-bzr diff $(@D)/testMatlabDriver.m
	-bzr diff $(@D)/testMatlab_odes.m
	-bzr diff $(@D)/testMatlab_r.m
	-bzr diff $(@D)/testMatlab_s.m
	-bzr diff $(@D)/testMatlab.ma
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/testMatlab/testMatlab_misc.log : FORCE
	cd $(@D); rm -f testMatlab_misc.log testMatlab_miscScript.log testMatlab_miscDriver.m testMatlab_misc_odes.m testMatlab_misc_r.m testMatlab_misc_s.m
	./facile.pl -m -o $(@D)/testMatlab_misc $(@D)/testMatlab_misc.eqn 2>&1 | tee -a $(@D)/testMatlab_misc.log
	@echo "***********************************************************************************************"
	@echo "PLEASE VIEW MATLAB RESULTS, THEN TYPE EXIT AND INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	cd $(@D); matlab -nodesktop -nosplash -logfile testMatlab_miscScript.log -r testMatlab_miscScript 2>&1 | tee -a testMatlab_misc.log
	-bzr diff $(@D)/testMatlab_misc.log
	-bzr diff $(@D)/testMatlab_miscScript.log
	-bzr diff $(@D)/testMatlab_miscDriver.m
	-bzr diff $(@D)/testMatlab_misc_odes.m
	-bzr diff $(@D)/testMatlab_misc_r.m
	-bzr diff $(@D)/testMatlab_misc_s.m
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/steady_state/%.log : FORCE
	cd $(@D); rm -f $*.log $*Script.log $*Driver.m $*_odes.m $*_r.m $*_s.m
	./facile.pl -m -P -o $(@D)/$* $(@D)/$*.eqn 2>&1 | tee -a $(@D)/$*.log
	@echo "***********************************************************************************************"
	@echo "PLEASE VIEW MATLAB RESULTS, THEN TYPE EXIT AND INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	cd $(@D); matlab -nodesktop -nosplash -logfile $*Script.log -r $*Script 2>&1 | tee -a $*.log
	-bzr diff $(@D)/$*.log
	-bzr diff $(@D)/$*Script.log
	-bzr diff $(@D)/$*Driver.m
	-bzr diff $(@D)/$*_odes.m
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/testStoch/GTPase.log : FORCE
	cd $(@D); rm -f GTPase.log GTPase_simulation_input GTPase_convert.m
	./facile.pl -s -o $(@D)/GTPase $(@D)/GTPase.eqn 2>&1 | tee -a $(@D)/GTPase.log
	@echo "Please inspect differences in file output for problems."
	-bzr diff $(@D)/GTPase.log
	-bzr diff $(@D)/GTPase_simulation_input
	-bzr diff $(@D)/GTPase_convert.m
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/testStoch/DynRates.log : FORCE
	cd $(@D); rm -f DynRates.log DynRates_simulation_input DynRates_convert.m
	./facile.pl -s -o $(@D)/DynRates $(@D)/DynRates.eqn 2>&1 | tee -a $(@D)/DynRates.log
	@echo "Please inspect differences in file output for problems."
	-bzr diff $(@D)/DynRates.log
	-bzr diff $(@D)/DynRates_simulation_input
	-bzr diff $(@D)/DynRates_convert.m
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/repression/repression.log : FORCE
	cd $(@D); rm -f repression.log repression_simulation_input repression_convert.m
	./facile.pl -s -o $(@D)/repression $(@D)/repression.eqn 2>&1 | tee -a $(@D)/repression.log
	@echo "Please inspect differences in file output for problems."
	-bzr diff $(@D)/repression.log
	-bzr diff $(@D)/repression_simulation_input
	-bzr diff $(@D)/repression_convert.m
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/michaelis_menten/michaelis_menten.log : FORCE
	cd $(@D); rm -f michaelis_menten.log michaelis_menten.ma
	./facile.pl -L -M $(@D)/michaelis_menten.eqn 2>&1 | tee -a $(@D)/michaelis_menten.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	-bzr diff $(@D)/michaelis_menten.log
	-bzr diff $(@D)/michaelis_menten.ma
	-bzr diff $(@D)/michaelis_menten.maple
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/poisson/poisson.log : FORCE
	cd $(@D); rm -f poisson.log poisson.ma
	./facile.pl -M $(@D)/poisson.eqn 2>&1 | tee -a $(@D)/poisson.log
	./facile.pl -m --split $(@D)/poisson.eqn 2>&1 | tee -a $(@D)/poisson.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	-bzr diff $(@D)/poisson.log
	-bzr diff $(@D)/poisson.ma
	-bzr diff $(@D)/poissonDriver.m
	-bzr diff $(@D)/poisson_odes.m
	-bzr diff $(@D)/poisson_S.m
	-bzr diff $(@D)/poisson_R.m
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/config/config.log : FORCE
	cd $(@D); rm -f config.log configDriver.m config_odes.m config_ode_event.m config_r.m config_s.m
	./facile.pl -m $(@D)/config.eqn 2>&1 | tee -a $(@D)/config.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	-bzr diff $(@D)/config.log
	-bzr diff $(@D)/configDriver.m
	-bzr diff $(@D)/config_odes.m
	-bzr diff $(@D)/config_ode_event.m
	-bzr diff $(@D)/config_r.m
	-bzr diff $(@D)/config_s.m
	@echo "If there are no problems, you are now ready to commit source code and log files"

# AUTO/MOEITY TESTCASES

test/examples/cornish/cornish.log : FORCE
	cd $(@D); rm -f cornish.log cornish.c cornish.ma
	./facile.pl -a -o $(@D)/cornish $(@D)/cornish.eqn 2>&1 | tee -a $(@D)/cornish.log
	./facile.pl $(@D)/cornish.eqn 2>&1 | tee -a $(@D)/cornish.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	-bzr diff $(@D)/cornish.log
	-bzr diff $(@D)/cornish.c
	-bzr diff $(@D)/cornish.ma
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/dimerization/dimerization.log : FORCE
	cd $(@D); rm -f dimerization.log dimerization.c dimerization.ma
	./facile.pl -a -o $(@D)/dimerization $(@D)/dimerization.eqn 2>&1 | tee -a $(@D)/dimerization.log
	./facile.pl $(@D)/dimerization.eqn 2>&1 | tee -a $(@D)/dimerization.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	-bzr diff $(@D)/dimerization.log
	-bzr diff $(@D)/dimerization.c
	-bzr diff $(@D)/dimerization.ma
	@echo "If there are no problems, you are now ready to commit source code and log files"


test/examples/Markevich/Markevich.log : FORCE
	cd $(@D); rm -f Markevich.log Markevich.c Markevich.ma
	./facile.pl -a -o $(@D)/Markevich $(@D)/Markevich.eqn 2>&1 | tee -a $(@D)/Markevich.log
	./facile.pl $(@D)/Markevich.eqn 2>&1 | tee -a $(@D)/Markevich.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	-bzr diff $(@D)/Markevich.log
	-bzr diff $(@D)/Markevich.c
	-bzr diff $(@D)/Markevich.ma
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/loop_and_chain/loop_and_chain.log : FORCE
	cd $(@D); rm -f loop_and_chain.log loop_and_chain.c loop_and_chain.ma
	./facile.pl -a -o $(@D)/loop_and_chain $(@D)/loop_and_chain.eqn 2>&1 | tee -a $(@D)/loop_and_chain.log
	./facile.pl $(@D)/loop_and_chain.eqn 2>&1 | tee -a $(@D)/loop_and_chain.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	-bzr diff $(@D)/loop_and_chain.log
	-bzr diff $(@D)/loop_and_chain.c
	-bzr diff $(@D)/loop_and_chain.ma
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/moiety_repeated_velocity/moiety_repeated_velocity.log : FORCE
	cd $(@D); rm -f moiety_repeated_velocity.log moiety_repeated_velocity.c moiety_repeated_velocity.ma
	./facile.pl -a -o $(@D)/moiety_repeated_velocity $(@D)/moiety_repeated_velocity.eqn 2>&1 | tee -a $(@D)/moiety_repeated_velocity.log
	./facile.pl $(@D)/moiety_repeated_velocity.eqn 2>&1 | tee -a $(@D)/moiety_repeated_velocity.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	@echo "WARNING: The reference C file is NOT correct"
	-bzr diff $(@D)/moiety_repeated_velocity.log
	-bzr diff $(@D)/moiety_repeated_velocity.c
	-bzr diff $(@D)/moiety_repeated_velocity.ma
	@echo "If there are no problems, you are now ready to commit source code and log files"

test/examples/PKC/PKC.log : FORCE
	cd $(@D); rm -f PKC.log PKC.c PKC.ma
	./facile.pl -a -o $(@D)/PKC $(@D)/PKC.eqn 2>&1 | tee -a $(@D)/PKC.log
	./facile.pl $(@D)/PKC.eqn 2>&1 | tee -a $(@D)/PKC.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	-bzr diff $(@D)/PKC.log
	-bzr diff $(@D)/PKC.c
	-bzr diff $(@D)/PKC.ma
	@echo "If there are no problems, you are now ready to commit source code and log files"

# SBML testcase
test/examples/sbml/michaelis_menten.log : FORCE
	cd $(@D); rm -f michaelis_menten.log michaelis_menten.ma
	./facile.pl -S $(@D)/michaelis_menten.eqn 2>&1 | tee -a $(@D)/michaelis_menten.log
	@echo "***********************************************************************************************"
	@echo "PLEASE INSPECT DIFFERENCES IN FILE OUTPUT FOR PROBLEMS."
	@echo "***********************************************************************************************"
	-bzr diff $(@D)/michaelis_menten.log
	-bzr diff $(@D)/michaelis_menten.sbml
	@echo "If there are no problems, you are now ready to commit source code and log files"


FORCE:

