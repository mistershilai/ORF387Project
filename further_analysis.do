clear all
global setdir "~/Documents/GitHub/ORF387Project"

* import medicare part D data (doc prescription rates)
import delim "$setdir/pharma_prescriber_network_data", clear // 3707 obs
rename (applicable_manufacturer_or_appli covered_recipient_npi total_opioid_payments) (company npi payments)
sum payments, d // get beginning stats

* isolate average payment rates for individual npi's by degrees
* challenge: want to collapse sum unique but collapse mean payments
collapse (mean) payments, by(npi) // should be 2026 obs
sum payments, d // get post collapse stats
* append degree values
frame create deg
frame deg: {
	import delim "$setdir/pharma_prescriber_network_data", clear
	rename (applicable_manufacturer_or_appli covered_recipient_npi total_opioid_payments) (company npi payments)
	gen degree = 1
	collapse (sum) degree, by(npi) // how many?
	* 1332+350+131+65+42+36+19+20+14+13+2+1+1=2026 chec!
	tab degree
}
frlink m:1 npi, frame(deg)
frget degree, from(deg) 
frame drop deg
drop deg

* for fun
reg payments degree, robust // great
reg payments degree if payments < 125, robust // removing outliers above 95% percentile
count if payments < 125

* graph
twoway (scatter payments degree if payments < 125 , msize(small)) ///
		(lfit payments degree if payments < 125) ///
		, xtitle("Degree of physician") ytitle("Average payment") ///
		title("Physician payments by connections (complete network)") ///
		xlabel(0(1)15, nogrid) ylabel(, nogrid) legend(ring(0) pos(4)) name(deg)
graph export "~/Documents/GitHub/ORF387Project/physiciansdegree.pdf", replace

**# analyzing Purdue Pharma partnerships
frame create pp
frame pp: {
	import delim "$setdir/pharma_prescriber_network_data", clear // 3707 obs
	rename (applicable_manufacturer_or_appli covered_recipient_npi total_opioid_payments) (company npi payments)
	keep if company == "Purdue Pharma L.P."
	isid npi // well that's good no one was paid more than once
	gen purdue = 1
}
frlink 1:1 npi, frame(pp)
frget purdue, from(pp)
frame drop pp
drop pp

**# analyzing depomed partnerships
frame create depo
frame depo: {
	import delim "$setdir/pharma_prescriber_network_data", clear // 3707 obs
	rename (applicable_manufacturer_or_appli covered_recipient_npi total_opioid_payments) (company npi payments)
	keep if company == "Depomed, Inc."
	isid npi // well that's good no one was paid more than once
	gen depomed = 1
}
frlink 1:1 npi, frame(depo)
frget depomed, from(depo)
frame drop depo
drop depo

* create orange dots just if purdue pharma link
gen purdue_times = purdue * payments
gen degree_offset = degree + 0.1

* graph with orange dots
twoway (scatter payments degree if payments < 125 , msize(tiny)) ///
		(scatter purdue_times degree_offset if payments < 125 , msize(tiny)) ///
		(lfit payments degree if payments < 125) ///
		, xtitle("Degree of physician") ytitle("Average payment") ///
		title("Physician payments by connections (complete network)") ///
		xlabel(, nogrid) ylabel(, nogrid) legend(ring(0) pos(4)) 
* this doesn't super work

* let's do a stacked bar
	* compute percentages
replace purdue = 0 if purdue == .
replace depomed = 0 if depomed == .

* purdue graph
preserve
collapse (mean) purdue, by(degree)

graph bar (asis) purdue, over(degree) ///
	ytitle("Percentage of physicians with link to Purdue Pharma") ///
	title("Percentage of physicians with link to Purdue Pharma, by degree groups") ///
	name(bar) //blabel(_N, pos(inside)) (doesn't work)
graph export "~/Documents/GitHub/ORF387Project/physiciansdegree_purduepercent.pdf", replace
restore

graph combine deg bar, cols(1) xcommon xsize(8) ysize(8)
* depomed graph
preserve
collapse (mean) depomed, by(degree)

graph bar (asis) depomed, over(degree) ///
	ytitle("Percentage of physicians with link to Depomed") ///
	title("Percentage of physicians with link to Depomed, by degree groups") ///
	name(bardepo) //blabel(_N, pos(inside)) (doesn't work)
graph export "~/Documents/GitHub/ORF387Project/physiciansdegree_depomedpercent.pdf", replace
restore



**# arcos graph 2017 PA
use "~/Documents/Princeton/JP/data/arcos_all", clear
keep if year >= 2010
keep if state == "PA"

* variables
egen opioid = rowtotal(drug_9143 drug_9050 drug_9300 drug_9801 drug_9193 drug_9150 drug_9230)
egen otheropioids = rowtotal(drug_9050 drug_9300 drug_9801 drug_9193 drug_9150 drug_9230)
rename drug_9143 oxycodone

* collapse values
collapse (sum) opioid oxycodone, by(year state)
gen otheropioid = opioid - oxycodone
gen percent = oxycodone / opioid

* stacked bar
graph bar oxycodone otheropioids , over(year) stack percentages ///
	title("PA Opioid drug shipments 2010-2018") ///
	legend(pos(6) label(1 "OxyContin") label(2 "Other opioids" ))
*graph export "~/Documents/GitHub/ORF387Project/PAdrugshipments.pdf", replace


**# physicians PA map
* ONLY NEED TO RUN ONCE
shp2dta using "$setdir/pa_zip_shapefile.shp", database("$setdir/pashapefile") coordinates("$setdir/pashapefilecoord") genid(id) // process shape file

/* dta shape files
use "$setdir/pashapefile", clear
use "$setdir/pashapefilecoord", clear
*/

* import physicians data
use "~/Documents/Princeton/JP/data/hospital_2011.dta", clear
keep if state == "PA"

* create map
* merge with cz1990 shapefile
rename zipcode96 ZCTA5CE
tostring ZCTA5CE, replace

merge 1:1 ZCTA5CE using "$setdir/pashapefile" // as good as its gonna get

*gen avoid = (strpos(cz90name, ",HI") > 0) | (strpos(cz90name, ",AK") > 0)
spmap physicians using "$setdir/pashapefilecoord", id(id) fcolor(Blues) title("PA physicians density in 2011") scalebar(units(1) ypos(-150))
graph export "$setdir/physiciansmap.jpg", replace
