using wgregseq, FASTX, DataFrames, CSV, BioSequences, CairoMakie, Jedi, StatsBase

# Ser plotting style
Jedi.styles.default_makie!()

# Set path
dir = @__DIR__
homedir = joinpath(split(dir, "/")[1:end-2])

# Import promoter list and infer types that can be infered automatically

# Promoters from Ecocyc
promoter_list_ecocyc = CSV.read(
    "/$homedir/data/promoter_list_ecocyc.csv", 
    DataFrame, 
    types=Dict(
        "promoter"=>String,
        "tss"=>Float64,
        "direction"=>String
    )
)

# Promoters from RegulonDB
promoter_list_regulonDB = CSV.read(
    "/$homedir/data/promoter_list_regulon_DB.csv", 
    DataFrame, 
    types=Dict(
        "promoter"=>String,
        "tss"=>Float64,
        "direction"=>String
    )
)

# Define custom function for nice imports
Base.parse(::Type{Vector{String}}, x::String) = Vector{String}(filter(x-> x != ", ", split(x, "\""))[2:end-1])
function Base.parse(::Type{Vector{T}}, x::String) where {T<: Real}
    number = split(split(x, "[")[end][1:end-1], ", ")
    number_list = T[]
    for num in number
        if num != ""
            push!(number_list, parse(T, num))
        else
            return push!(number_list, NaN)
        end
    end
    return number_list

end
Base.parse(::Type{Vector{String}}, x::Missing) = String[]
Base.parse(::Type{Vector{Float64}}, x::Missing) = Float64[]

# Replace columns by nicer types
promoter_list_ecocyc.genes = parse.(Vector{String}, promoter_list_ecocyc.genes)
promoter_list_ecocyc.gene_position = parse.(Vector{Float64}, promoter_list_ecocyc.gene_position)

promoter_list_regulonDB.genes = parse.(Vector{String}, promoter_list_regulonDB.genes)
promoter_list_regulonDB.gene_position = parse.(Vector{Float64}, promoter_list_regulonDB.gene_position)


# Join the datasets
_df = promoter_list_ecocyc[(.~ isnan.(promoter_list_ecocyc.tss)) .& (map(x-> x != ["None"], promoter_list_ecocyc.genes)), :]
promoter_list_regulonDB.tss = coalesce.(promoter_list_regulonDB.tss, NaN)
append!(_df, promoter_list_regulonDB)

##

# Drop missing entries
dropmissing!(_df)
_df.direction = convert(Vector{String}, _df.direction)

# Sort gene entries to remove duplicates
for i in 1:nrow(_df)
    genes, positions = _df[i, ["genes", "gene_position"]]
    index = sortperm(genes)
    _df[i, ["genes", "gene_position"]] = genes[index], positions[index]
end

# Alphabetically sort dataframe and remove duplicates
sort!(_df, "genes")
df = unique(_df)
df = df[5:end, :]

CSV.write("/$homedir/data/promoter_list_processed.csv", df)

##

min_distance = Float64[]
for i in 1:nrow(df)
    min_dist = minimum(abs.(df.gene_position[i] .- df.tss[i]))
    push!(min_distance, min_dist)
end 

df[!, "distance"] = min_distance
min_distance = min_distance[.~ isnan.(min_distance)]
sort!(df, "distance", rev=true)
println(first(df[.~isnan.(df.distance), ["genes", "distance"]], 15))
##
fig = Figure(resolution=(300, 300))
ax = Axis(fig[1, 1], xscale=log10)
ax.xlabel = "Bases"
ax.ylabel = "ECDF"
ax.title = "Distance of TSS to coding region"
ind = findfirst(x -> x > 0, sort(min_distance))
lines!(
    ax, 
    sort(min_distance)[ind:end], 
    collect(ind:length(min_distance)) ./ length(min_distance),
    linewidth=3
)
fig

## Save Results
save("figures/tss_distance.pdf", fig)


##

df = CSV.read("/$home_dir/data/all_genes_table.csv", DataFrame)[1:end-1, :]
_df = _df[map(x -> length(x)>0, _df.genes), :]
gdf = groupby(_df, "promoter")

gene_promoter = []
for group in gdf
    push!(gene_promoter, group.genes...)
end
genes_w_promoter = unique(vcat(gene_promoter...))
genes_wo_promoter = filter(x -> x ∉ genes_w_promoter, df.gene)
println("Percentage of genes without a promoter: $(length(genes_wo_promoter)/(length(genes_wo_promoter)+length(genes_w_promoter)))")