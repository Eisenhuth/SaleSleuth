import Foundation
import universalis_swift
import xivapi_swift
import Progress
import Rainbow

@main
struct Sleuth{
    
    static func main() async throws {
        
        let universalis = UniversalisClient()
        let xivapi = xivapiClient()
        
        let textColor = "#F05138"
        
        print("enter the World/Data Center on which to check the market".hex(textColor))
        guard let world = readLine() else { exit(0) }
        guard let worlds = await universalis.getWorlds().result else { print("could not get worlds, exiting"); exit(0) }
        guard let datacenters = await universalis.getDataCenters().result else { print("could not get data centers, exiting"); exit(0) }
        
        if !worlds.contains(where: { $0.name == world }) && !datacenters.contains(where: { $0.name == world }) {
            print("world/data center not recognized, exiting")
            exit(0)
        }
        
        print("enter the Retainer Names you want to look up (comma separated)".hex(textColor))
        guard let input = readLine() else { exit(0) }
        
        if input.isEmpty {
            print("no names entered, exiting")
            exit(0)
        }
        
        let names: [String] = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        var itemNames = [Int : String]() //storing itemNames here to limit xivapi calls
        var marketData = [CurrentlyShownView]()
        var results = [String]()
        var runningTotal = 0
        
        print("fetching ItemIDs of marketable items..".hex(textColor))
        let marketableItems = await universalis.getMarketableItems().result
        let chunks = marketableItems?.chunked(into: 100)
        print("total marketable items: \(marketableItems?.count ?? 0)".green)
        
        print("fetching \(world) market data".hex(textColor))
        for chunk in Progress(chunks ?? [], configuration: [ProgressBarLine(), ProgressPercent(decimalPlaces: 2), ProgressTimeEstimates()]) {
            var currentData = await universalis.getCurrentData(worldDcRegion: world, itemIds: chunk, queryItems: nil).result
            
            while currentData == nil {
                try? await Task.sleep(for: .milliseconds(250))
                //this shouldn't happen
                currentData = await universalis.getCurrentData(worldDcRegion: world, itemIds: chunk, queryItems: nil).result
            }
            
            currentData?.items?.values.forEach({ currentlyShownView in
                marketData.append(currentlyShownView)
            })
        }
        
        let totalListings = marketData.reduce(0) { $0 + ($1.listings?.count ?? 0) }.formatted()
        print("processing \(world) market data (\(totalListings) listings)".hex(textColor))
        for data in Progress(marketData, configuration: [ProgressBarLine(), ProgressPercent(decimalPlaces: 2), ProgressTimeEstimates()]) {
            guard let listings = data.listings else { continue }
            
            let itemID = data.itemID
            
            for listing in listings {
                guard let retainerName = listing.retainerName else { continue }
                if names.contains(retainerName){
                    
                    if !itemNames.keys.contains(itemID) {
                        let itemName = await xivapi.getItemMinimal(itemID)?.name
                        itemNames[itemID] = itemName != nil ? itemName : itemID.description
                    }
                    
                    let result = "\(retainerName) - \(itemNames[itemID] ?? itemID.description) x\(listing.quantity) @ \(listing.pricePerUnit.formatted()) gil/each"
                    
                    results.append(result)
                    runningTotal += listing.total
                }
            }
        }
        
        if results.count > 0 {
            print("-- results: \(results.count) --".green)
            results.sorted().forEach { print($0) }
            print("total value: \(runningTotal.formatted(.number)) gil")
        } else {
            print("no matches".red)
        }
    }
}
