package:
	if [ -e galaxykubeman/charts ] ; then rm galaxykubeman/charts ; fi
	cd galaxykubeman ; helm dep up
	ls galaxykubeman/charts
	helm package galaxykubeman
	mv *.tgz ../helm_charts
	
help:
	@echo "\nGOALS:"
	@echo "   package - package the chart and copy to local repo"
	@echo "   help    - print this help message"
	@echo "\nThe default goal is 'package'\n"
