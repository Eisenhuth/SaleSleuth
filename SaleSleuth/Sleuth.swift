import Foundation
import universalis_swift
import xivapi_swift
import Progress

@main
struct Sleuth{
    
    static func main() async throws {
        
        let universalis = UniversalisClient()
        let xivapi = xivapiClient()
        
        print("enter the World on which to check the market")
        if let world = readLine() {
            
            
            if let worlds = await universalis.getWorlds() {
                if !worlds.contains(where: { $0.name == world }) {
                    print("world not recognized, exiting")
                    exit(0)
                }
            }
            
            print("enter the Retainer Names you want to look up (comma separated)")
            if let input = readLine() {
                
                let names: [String] = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                
                var itemNames = [Int : String]() //storing itemNames here to limit xivapi calls
                var marketData = [CurrentlyShownView]()
                var results = [String]()
                var runningTotal = 0
                
                
                print("fetching IDs of marketable items")
                let marketableItems = await universalis.getMarketableItems()
                let chunks = marketableItems?.chunked(into: 100)
                print("split \(marketableItems?.count ?? 0) itemIDs into \(chunks?.count ?? 0) chunks")
                
                print("fetching \(world) market data")
                for chunk in Progress(chunks ?? []) {
                    var currentData = await universalis.getCurrentData(worldDcRegion: world, itemIds: chunk, queryItems: nil)
                    
                    while currentData == nil { //this shouldn't happen
                        currentData = await universalis.getCurrentData(worldDcRegion: world, itemIds: chunk, queryItems: nil)
                    }
                    
                    Task {
                        currentData?.items?.values.forEach({ currentlyShownView in
                            marketData.append(currentlyShownView)
                        })
                    }
                }
                
                print("going through market data")
                for data in Progress(marketData) {
                    if let listings = data.listings {
                        
                        let itemID = data.itemID
                        
                        for listing in listings {
                            if let retainerName = listing.retainerName {
                                if names.contains(retainerName){
                                    
                                    if !itemNames.keys.contains(itemID) {
                                        var itemName = await xivapi.getItemName(itemId: itemID)?.Name
                                        
                                        while itemName == nil { //this shouldn't happen
                                            itemName = await xivapi.getItemName(itemId: itemID)?.Name
                                        }
                                        
                                        itemNames[itemID] = itemName
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
                    print("-- results: \(results.count) --")
                    results.sorted().forEach { print($0) }
                    print("total value: \(runningTotal.formatted(.number)) gil")
                } else {
                    print("no matches")
                }
                
            } else {
                print("no names entered, exiting")
            }
        } else {
            print("no world entered, exiting")
        }
        
        
    }
}
