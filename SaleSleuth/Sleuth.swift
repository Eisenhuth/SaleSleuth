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
        
        print("enter the World on which to check the market".hex(textColor))
        if let world = readLine() {
            
            
            if let worlds = await universalis.getWorlds().result {
                if !worlds.contains(where: { $0.name == world }) {
                    print("world not recognized, exiting")
                    exit(0)
                }
            }
            
            print("enter the Retainer Names you want to look up (comma separated)".hex(textColor))
            if let input = readLine() {
                
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
                        try? await Task.sleep(for: .seconds(1))
                        //this shouldn't happen
                        currentData = await universalis.getCurrentData(worldDcRegion: world, itemIds: chunk, queryItems: nil).result
                    }
                    
                    Task {
                        currentData?.items?.values.forEach({ currentlyShownView in
                            marketData.append(currentlyShownView)
                        })
                    }
                }
                
                print("processing \(world) market data".hex(textColor))
                for data in Progress(marketData, configuration: [ProgressBarLine(), ProgressPercent(decimalPlaces: 2), ProgressTimeEstimates()]) {
                    if let listings = data.listings {
                        
                        let itemID = data.itemID
                        
                        for listing in listings {
                            if let retainerName = listing.retainerName {
                                if names.contains(retainerName){
                                    
                                    if !itemNames.keys.contains(itemID) {
                                        var itemName = await xivapi.getItemMinimal(itemID)?.name
                                        itemNames[itemID] = itemName != nil ? itemName : itemID.description
                                    }
                                    
                                    let result = "\(retainerName) - \(itemNames[itemID] ?? itemID.description) x\(listing.quantity)"
                                    
                                    results.append(result)
                                    runningTotal += listing.taxedTotal
                                }
                            }
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
                
            } else {
                print("no names entered, exiting".red)
            }
        } else {
            print("no world entered, exiting".red)
        }
        
        
    }
}
