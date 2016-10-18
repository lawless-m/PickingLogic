module FifoData

using ExcelReaders
using Base.Dates
using DataArrays

include("utils.jl")
          
export LOCWH, FIFO
		  
const LOCWH = begin
	xl = @sheet("prtnum_stoloc_whentry.xls", "prtnum_stoloc_whentry")
	lw = Dict{AbstractString, Vector{Tuple{Int64, AbstractString}}}() # stoloc => (prtnum, warehouse_id)
	for r in 2:size(xl)[1]
		@push!(lw, @dena(xl[r,2]), (i64(xl[r,1]), @dena(xl[r,3])))
	end
	lw
end

const FIFO = begin
	xl = @sheet("prtnum_lodnum_subnum_fifdte_unyqty_whentry.xls", "prtnum_lodnum_subnum_fifdte_unyqty_whentry")
	fif = Dict{Int64, Vector{Tuple{AbstractString, AbstractString, Int64, AbstractString, Int64, AbstractString}}}() # prtnum => (lodnum, casenum, fifoday, fifotime, qty, whid)
	for r in 2:size(xl)[1]
		@push!(fif, i64(xl[r,1]), (@dena(xl[r,2]), @dena(xl[r,3]), iday(xl[r,4]), ttime(xl[r,4]), i64(xl[r,5]), @dena(xl[r,6])))
	end
	fif
end



end