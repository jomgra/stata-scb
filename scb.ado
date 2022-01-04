/*

	S C B 
	
	Program som hämtar statistik från SCB:s statistikdatabas. 
	Programmet kräver att följande program är installerade:
	
		libjson (ssc install libjson)
		insheetjson (ssc install insheetjson)
		
*/

// Ange adressen (URL) till SCB:s API för statistikdatabasen
global scbapirooturl = "http://api.scb.se/OV0104/v1/doris/sv/ssd/"

// Sökväg till fil där felmeddelanden sparas
global scberrorlog = "C:\Lokala\Temp\powershell_errormsg.txt"

// Sökväg till tillfällig utdatafil (som raderas efter att den använts)
global scboutput = "C:\Lokala\Temp\powershell_output.csv"


program scb
	qui  {
		if "`*'"=="?" {
			noi scbhelp
			exit
			}
			
		if `c(N)' > 0 error 18
	
		//local numarg = (length("`*'") - length(subinstr("`*'", " ", "", .))) + ("`*'"!="")
		local p = subinstr("`*'"," ","/",.)

		scbjsoncheck "`p'/"

		if r(list)=="1" { // OM DET ÄR EN LISTA
			clear
			set linesize 255
			gen str100 id = ""
			gen str100 ty = ""
			gen str1000 te = ""
			capture insheetjson i ty te using "$scbapirooturl`p'/", col ("id" "type" "text")
			if _rc!=0 scberror
			compress

			local strsize = real(substr("`: type id'", 4,.))
			local tab = 3
			local spaces = " " * 100
			local lines = "-" * 100
			if ty[1] == "t" {
				local heading = "TABELL"
				}
			else {
				local heading = "ÄMNE"
			}
			
			if (`c(N)'!=0) {
				local output = "ID" + substr("`spaces'",1,(`strsize' + (`tab'-2))) + "`heading'"
				noi di _newline "`output'"
				local output = substr("`lines'", 1,`strsize') + substr("`spaces'",1,`tab') + "`lines'"
				noi di "`output'"

				forvalues n= 1/`c(N)' {
					local cid = strltrim(id[`n'])
					local ctext = te[`n']
					local output = "{stata scb `*' `cid':`cid'}" + substr("`spaces'",1,(`strsize' + `tab')-length("`cid'"))+"`ctext'"
					noi di "`output'"
				}
			}
		clear
		}
		else { // OM DET ÄR DATA (EN TABELL)
			
			gen str1000 code=""
			capture insheetjson code using "$scbapirooturl`p'/", col ("code") tableselector("variables")
			if _rc!=0 scberror
			
			forvalues n= 1/`c(N)' {
				local value = code[`n']
				if "`filter'"!="" {
					local filter = "`filter',"
				}
				local filter = "`filter'{'code':'`value'','selection':{'filter':'all','values': ['*']}}"
			}

			local cmd = `"(Invoke-WebRequest -Uri $scbapirooturl`p'/ -Method POST -Body (\"{'query' : [`filter'] , 'response':{'format':'csv'}}\") -ContentType \"application/json\" -Outfile \"$scboutput\")"'

			capture ! powershell -windowstyle hidden -Command "`cmd'" > $scberrorlog
			if _rc!=0 scberror
			
			capture import delimited "$scboutput", varnames(1) stripquote(yes) clear 
			if _rc!=0 scberror
						
			compress
			erase "$scboutput"
		
		}
	}
end

program scbjsoncheck, rclass
	clear
	if strlen("`1'") > 2 {
		gen str1000 t = ""
		capture insheetjson t using "$scbapirooturl`1'/", col ("title")
		if _rc!=0 scberror
		return local list = (t[1]=="")
	}
	else {
		return local list = "1"
	}
end

program scberror
	local link = substr("$scberrorlog", 3, .)
	di in red "Fel ( {stata scb ?:hjälp} | {view `link':log} )
	err _rc
end

program scbhelp

	di _newline "--------------------------------------------------------------------------------" 
	di " SCB-PROGRAMMET"
	di _newline "  Programmet gör det möjligt att ladda ner aktuell"
	di "  statistik från Statistiska centralbyrån (SCB)."
	di _newline "  Ange sökvägen till den statistik du vill ladda in."
	di "  Använd följande format:"
	di _newline "      scb <id> <id> <id>"
	di _newline "      ex. scb JO JO1104 F1NY"
	di _newline "  Programmet kräver att du har installerat {stata ssc describe libjson:libjson} och {stata ssc describe insheetjson:insheetjson}."
	di _newline "--------------------------------------------------------------------------------" _newline 

end
