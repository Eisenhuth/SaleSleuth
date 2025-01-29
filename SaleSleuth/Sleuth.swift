import Foundation
import universalis_swift
import xivapi_swift
import Rainbow
import Algorithms

@main
struct Sleuth{
    
    static func main() async throws {
        
        let universalis = UniversalisClient()
        let xivapi = xivapiClient()
        let maxTasks = 4
        
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
        
        print("fetching ItemIDs of marketable items..".hex(textColor))
        let marketableItems = await universalis.getMarketableItems().result
        guard let chunks = marketableItems?.chunks(ofCount: 100) else { exit(0) }
        print("total marketable items: \(marketableItems?.count ?? 0)".green)
        
        print("fetching \(world) market data".hex(textColor))
        
        let marketData = await withTaskGroup(of: [CurrentlyShownView].self) { group in
            var runningTasks = 0
            var chunkIterator = chunks.makeIterator()
            var collected = [CurrentlyShownView]()
            
            while let chunk = chunkIterator.next() {
                if runningTasks >= maxTasks {
                    if let result = await group.next() { collected.append(contentsOf: result) }
                    runningTasks -= 1
                }
                
                group.addTask {
                    let currentData = await universalis.getCurrentData(worldDcRegion: world, itemIds: chunk.map { $0 })
                    if currentData.statusCode != 200 { print("[\(currentData.statusCode?.description ?? "")] - failed to fetch data for \(chunk)") }
                    
                    return currentData.result?.items?.map { $0.value } ?? []
                }
                
                runningTasks += 1
            }
            
            for await listing in group {
                collected.append(contentsOf: listing)
            }
            
            return collected
        }
        
        let retainerNames: [String] = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let matchingData = marketData.filter { $0.listings?.filter({ retainerNames.contains($0.retainerName ?? "") }).count ?? 0 > 0 }
        let matchingItemIds = Set(matchingData.map { $0.itemID }).map { $0 }
        let items: [ItemMinimal]? = await xivapi.getSheetRows(.Item, rows: matchingItemIds, queryItems: [URLQueryItem(name: "fields", value: "Name,Icon,Description")])
        
        var results = [String]()
        var runningTotal = 0
        var itemNames = [Int : String]()
        items?.forEach({ itemNames[$0.row_id] = $0.name })
                
        for data in matchingData {
            guard let listings = data.listings else { continue }
            let matches = listings.filter ({ retainerNames.contains($0.retainerName ?? "") })
            matches.forEach { listing in
                runningTotal += listing.total
                let result = "\(listing.retainerName ?? "[retainer name]") - \(itemNames[data.itemID] ?? data.itemID.description) x\(listing.quantity) @ \(listing.pricePerUnit.formatted()) gil/each"
                results.append(result)
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
