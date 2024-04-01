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
                var results = [String]()
                var runningTotal = 0
                
                
                print("fetching IDs of marketable items")
                let marketableItems = await universalis.getMarketableItems()
                let chunks = marketableItems?.chunked(into: 100)
                print("split \(marketableItems?.count ?? 0) itemIDs into \(chunks?.count ?? 0) chunks")
                print("going through chunks")
                
                
                for chunk in Progress(chunks ?? []) {                    
                    var result = await universalis.getCurrentData(worldDcRegion: world, itemIds: chunk, queryItems: nil)
                    
                    while result == nil { //this shouldn't happen
                        result = await universalis.getCurrentData(worldDcRegion: world, itemIds: chunk, queryItems: nil)
                    }
                    
                    if let values = result?.items?.values {
                        
                        //each value is a CurrentlyShownView
                        for value in values {
                            if let listings = value.listings {
                                
                                //go through each listing (ListingView)
                                for listing in listings {
                                    Task {
                                        if let retainerName = listing.retainerName {
                                            if names.contains(retainerName){
                                                
                                                if !itemNames.keys.contains(value.itemID) {
                                                    var itemName = await xivapi.getItemName(itemId: value.itemID)?.Name
                                                    
                                                    while itemName == nil { //this shouldn't happen
                                                        itemName = await xivapi.getItemName(itemId: value.itemID)?.Name
                                                    }
                                                    
                                                    itemNames[value.itemID] = itemName
                                                }
                                                
                                                let result = "\(retainerName) - \(itemNames[value.itemID] ?? value.itemID.description) x\(listing.quantity)"
                                                results.append(result)
                                                runningTotal += listing.taxedTotal
                                            }
                                        }
                                    }
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
