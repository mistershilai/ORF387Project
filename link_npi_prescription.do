clear all
global setdir "~/Documents/GitHub/ORF387Project"

* import medicare part D data (doc prescription rates)
import delim "$setdir/padrugs2017", clear

* import pharma - doctor data network and isolate all unique doctors
frame create pharma
frame pharma: {
	import delim "$setdir/pharma_prescriber_network_data.csv", clear
	rename covered_recipient_npi prscrbr_npi
	bysort prscrbr_npi: gen unique = 1 if _n == 1
	keep if unique == 1 // now 2026 obs
	keep prscrbr_npi unique
}


* drop npi in medpartD if npi not in pharma network (2026 distinct npi's)
frlink m:1 prscrbr_npi, frame(pharma)
frget unique, from(pharma)
tab unique, m
drop if unique != 1 // leaves 138,997 obs that are for doctors that are in existing network

* replace original pharma data
frame pharma: import delim "$setdir/pharma_prescriber_network_data.csv", clear

* save this
save "$setdir/medpartDCMSdoctors", replace

* keep relevant vars
use "$setdir/medpartDCMSdoctors", clear
keep prscrbr_npi prscrbr_type brnd_name gnrc_name tot_clms tot_day_suply

* which drugs are represented? (need to identify manufacturer of drugs in default data)
frame create codes
frame codes {
	import delim "$setdir/codes.csv", clear
	keep propname labelname
	duplicates drop
	
	* keep pharma companies that matter: (24 distinct companies)
	replace labelname = "PFIZER INC." if strpos(labelname, "Pfizer Inc") > 0
	replace labelname = "Mallinckrodt LLC" if strpos(labelname, "Mallinckrodt") > 0
	replace labelname = "Mallinckrodt LLC" if strpos(labelname, "MALLINCKRODT") > 0
	replace labelname = "Pernix Therapeutics Holdings, Inc" if strpos(labelname, "Pernix Therapeutics") > 0
	replace labelname = "Purdue Pharma L.P." if strpos(labelname, "Purdue Pharma") > 0
	replace labelname = "Braeburn Pharmaceuticals, Inc." if strpos(labelname, "Braeburn Pharmaceuticals") > 0
	replace labelname = "Braeburn Pharmaceuticals, Inc." if strpos(labelname, "Braeburn Pharmaceuticals") > 0
	replace labelname = "Egalet US Inc" if strpos(labelname, "Egalet US Inc") > 0
	replace labelname = "INSYS Therapeutics Inc" if strpos(labelname, "Insys Therapeutics, Inc") > 0
	keep if labelname == "Akrimax Pharmaceuticals, LLC" | labelname == "BioDelivery Sciences International Inc" | labelname == "Braeburn Pharmaceuticals, Inc." | labelname == "Collegium Pharmaceutical, Inc." | labelname == "Daiichi Sankyo Inc." | labelname == "Depomed, Inc." | labelname == "Egalet US Inc" | labelname == "Endo Pharmaceuticals, Inc." | labelname == "Fresenius Kabi USA, LLC" | labelname == "INSYS Therapeutics Inc" | labelname == "Indivior Inc." | labelname == "Mallinckrodt LLC" | labelname == "Mission Pharmacal Company" | labelname == "Mylan Institutional Inc." | labelname == "Mylan Pharmaceuticals Inc." | labelname == "Mylan Specialty L.P." | labelname == "Orexo US, Inc." | labelname == "PFIZER INC." | labelname == "Pernix Therapeutics Holdings, Inc" | labelname == "Purdue Pharma L.P." | labelname == "Sentynl Therapeutics, Inc." | labelname == "The Medicines Company" | labelname == "Vertical Pharmaceuticals, LLC"
	
	distinct labelname // should be 23 bc one (Purdue Transdermal) is not represented
	
	* make isid brndname work
	duplicates tag propname, gen(tag)
	sort propname
	* need to cmobine mylan pharma and mylan institutional because they have the same drugs
	replace labelname = "Mylan Pharmaceuticals Inc." if labelname == "Mylan Institutional Inc."
	* assign duplicate drugs to someone:
	drop if propname == "Chlorothiazide" & labelname == "Mylan Pharmaceuticals Inc."
	drop if propname == "Clonidine" & labelname == "Mylan Pharmaceuticals Inc."
	drop if propname == "Doxorubicin Hydrochloride" & labelname == "Fresenius Kabi USA, LLC"
	drop if propname == "Etoposidee" & labelname == "Mylan Pharmaceuticals Inc."
	drop if propname == "Fluorouracil" & labelname == "Mylan Pharmaceuticals Inc."
	drop if propname == "Fluorouracil" & labelname == "Mylan Pharmaceuticals Inc."
	drop if propname == "Folic Acid"
	drop if propname == "Glycopyrrolate"
	drop if propname == "Heparin Sodium"
	drop if propname == "Hydralazine Hydrochloride"
	drop if propname == "Ketorolac Tromethamine"
	drop if propname == "Leucovorin Calcium"
	drop if propname == "Metoclopramide"
	drop if propname == "Metronidazole" & labelname == "Mylan Pharmaceuticals Inc."
	drop if propname == "Midazolam" & labelname == "Fresenius Kabi USA, LLC"
	drop if propname == "Morphine Sulfate"
	drop if propname == "RECOTHROM" & labelname == "Mallinckrodt LLC"
	drop if propname == "Rocuronium" & labelname == "Fresenius Kabi USA, LLC"
	drop if propname == "Sumatriptan Succinate"
	drop if propname == "Ciprofloxacin"
	drop if propname == "Venlafaxine Hydrochloride"
	
	gen brndname = lower(propname)
	drop propname
	duplicates drop
	drop tag
	duplicates tag brndname, gen(tag)
	drop if labelname == "Fresenius Kabi USA, LLC" & tag == 1
	drop tag
	duplicates tag brndname, gen(tag)
	drop if tag > 0
	drop tag
	isid brndname
}

* rename for merge in default
gen brndname = lower(brnd_name)

* merge prescriptions to doctors
frlink m:1 brndname, frame(codes) // 120,000 unmatched
frget labelname, from(codes)

drop if labelname == "" // 55,000 obs left
distinct labelname // 16 companies
distinct brndname // 237 drugs

frame copy default default2

* isolate opioid drugs
frame change default
keep if brndname == "butorphanol tartrate" | ///
         brndname == "butrans" | ///
         brndname == "fentanyl" | ///
         brndname == "hysingla er" | ///
         brndname == "levorphanol tartrate" | ///
         brndname == "ms contin" | ///
         brndname == "oxaydo" | ///
         brndname == "oxycontin" | ///
         brndname == "percocet" | ///
         brndname == "sublocade" | ///
         brndname == "suboxone" | ///
         brndname == "zubsolv" // now 898 obs
distinct labelname // 6 companies
distinct brndname // 10 drugs

* create measure
collapse (sum) tot_day_suply tot_clms, by(labelname prscrbr_npi) //1911 obs
rename tot_day_suply opioid_day_suply
rename tot_clms opioid_clms

* link with doctor network
frame change pharma
frame pharma: import delim "$setdir/pharma_prescriber_network_data.csv", clear //3707 obs
rename (applicable_manufacturer_or_appli covered_recipient_npi) (labelname prscrbr_npi)

frlink 1:1 prscrbr_npi labelname, frame(default)
frget opioid_day_suply opioid_clms, from(default)

* do with all drugs (including non opioid):
frame change default2 // 55,000 obs
distinct labelname // 16 companies
distinct brndname // 237 drugs
collapse (sum) tot_day_suply tot_clms, by(labelname prscrbr_npi) // 5000 obs
frame change pharma
frlink 1:1 prscrbr_npi labelname, frame(default2)
frget tot_day_suply tot_clms, from(default2)
drop default*

count if missing(tot_day_suply)
count if missing(opioid_day_suply)

*gen diff = tot_day_suply - opioid_day_suply

* save
label var opioid_day_suply "prescriptions of opioid daily supply 2017"
label var tot_day_suply "prescriptions of all drugs daily supply 2017"
label var opioid_clms "opioid prescription claims 2017"
label var tot_clms "all drugs claims 2017"
export delim "$setdir/pharma_prescriber_network_data_weights.csv", replace // 712 913

/*
frame change default
frame change default2
frame change pharma
frame change codes
*/

/* keep just opioid
import delim "$setdir/pharma_prescriber_network_data_weights.csv", clear
keep if !missing(opioid_day_suply)
export delim "$setdir/pharma_prescriber_network_data_weights_onlyopioid.csv", replace // obs
*/
