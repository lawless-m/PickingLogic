cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))

using Base.Dates
using HIARP
using XlsxWriter

include("utils.jl")

#=

Can you run a Shipping Billing report for a 12 month period for only ATU as the consignee.  This should also allow us to see the number of shipments we made from MAI to IAH.  I believe the transport costs are billed by the FTZ not CLC.  We'll need to track down these transport invoices to HAI for the same period you run your report.

We can use this data to model what labor cost would be needed if HWL did the ATU orders in IAH vs MIA.

Can you run this report outlined below and send it tomorrow.  I'll be traveling through mid day tomorrow.  Seems we have another requirement in EWR.

Send me an expanded monthly outbound billing report with ship to consignee included 


I can filter from there.  But do need 12 month sample.  Might be easier to run 4 - 3 month reports

Understand.  Can you run a report listing the "ordnum" with ship to/consignee name?  I can use this with the existing billing reports I already to filter out ATU.
Best regards,

=#


df = qsql("list shipments for display WHERE ship_id like '%' AND wh_id =  'MFTZ' and rownum <10")

