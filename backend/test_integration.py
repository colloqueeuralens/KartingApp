#!/usr/bin/env python3
"""
Simple integration test for the karting WebSocket parser and HTML scraper
Tests the complete data flow: WebSocket parsing + HTML scraping + data fusion
"""
import asyncio
import json
from app.analyzers.karting_parser import KartingMessageParser
from app.services.html_scraper import KartingHtmlScraper
from app.services.driver_state_manager import DriverStateManager


async def test_websocket_parsing():
    """Test WebSocket message parsing (like drivers.py)"""
    print("🧪 Testing WebSocket parsing...")
    
    # Test circuit mappings (Apex timing format)
    circuit_mappings = {
        "C1": "Classement",
        "C2": "Kart", 
        "C3": "Equipe/Pilote",
        "C4": "Dernier T.",
        "C5": "Ecart",
        "C6": "Meilleur T.",
        "C7": "Tour"
    }
    
    # Initialize parser
    parser = KartingMessageParser(circuit_mappings)
    
    # Test WebSocket message (simulates real karting data)
    test_message = """r1c1|POS|1
r1c2|KART|25
r1c3|TEAM|Racing Team A
r1c4|LAP|1:23.456
r2c1|POS|2
r2c2|KART|42
r2c3|TEAM|Speed Devils
r2c4|LAP|1:24.123"""
    
    # Parse message
    result = parser.parse_message(test_message)
    
    if result['success']:
        print(f"✅ Parsed {len(result['drivers_updated'])} drivers successfully")
        for driver_id in result['drivers_updated']:
            mapped_data = result['mapped_data'][driver_id]
            print(f"   Driver {driver_id}: {mapped_data}")
    else:
        print(f"❌ Parsing failed: {result.get('error')}")
    
    return result


async def test_html_scraping():
    """Test HTML scraping (mock data since we need a real URL)"""
    print("\n🕷️ Testing HTML scraping...")
    
    # Mock HTML that simulates a timing page
    mock_html = """
    <table>
        <tr data-id="r1">
            <td class="no">25</td>
            <td class="dr">Racing Team A</td>
        </tr>
        <tr data-id="r2">
            <td class="no">42</td>
            <td class="dr">Speed Devils</td>
        </tr>
        <tr data-id="r0">
            <td class="no">Header</td>
            <td class="dr">Header</td>
        </tr>
    </table>
    """
    
    # Test HTML parsing directly
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(mock_html, 'html.parser')
    
    scraper = KartingHtmlScraper()
    static_data = await scraper._extract_driver_data_from_html(soup)
    
    if static_data:
        print(f"✅ Scraped static data for {len(static_data)} drivers")
        for driver_id, data in static_data.items():
            print(f"   Driver {driver_id}: {data}")
    else:
        print("❌ HTML scraping returned no data")
    
    return static_data


async def test_data_fusion():
    """Test complete data fusion (WebSocket + HTML + Firebase)"""
    print("\n🔄 Testing data fusion...")
    
    # Initialize driver state manager
    manager = DriverStateManager()
    
    # Mock circuit mappings
    circuit_mappings = {
        "C1": "Classement",
        "C2": "Kart", 
        "C3": "Equipe/Pilote",
        "C4": "Dernier T."
    }
    
    # Initialize with mappings
    manager.current_circuit_mappings = circuit_mappings
    manager.karting_parser = KartingMessageParser(circuit_mappings)
    
    # 1. Add WebSocket data
    websocket_message = "r1c1|POS|1\\nr1c4|LAP|1:23.456\\nr2c1|POS|2\\nr2c4|LAP|1:24.123"
    ws_result = await manager.process_websocket_message(websocket_message)
    
    # 2. Add static data (simulating HTML scraping)
    static_data_1 = {"Kart": "25", "Equipe/Pilote": "Racing Team A"}
    static_data_2 = {"Kart": "42", "Equipe/Pilote": "Speed Devils"}
    
    await manager.update_static_data("1", static_data_1)
    await manager.update_static_data("2", static_data_2)
    
    # 3. Check fusion results
    all_states = manager.get_all_driver_states()
    
    if all_states:
        print(f"✅ Data fusion successful for {len(all_states)} drivers")
        for driver_id, merged_state in all_states.items():
            print(f"   Driver {driver_id}: {merged_state}")
    else:
        print("❌ Data fusion failed")
    
    return all_states


async def main():
    """Run all integration tests"""
    print("🏁 Starting karting system integration tests...")
    
    try:
        # Test individual components
        ws_result = await test_websocket_parsing()
        html_result = await test_html_scraping()
        fusion_result = await test_data_fusion()
        
        # Summary
        print("\n📊 Test Summary:")
        print(f"   WebSocket parsing: {'✅' if ws_result.get('success') else '❌'}")
        print(f"   HTML scraping: {'✅' if html_result else '❌'}")
        print(f"   Data fusion: {'✅' if fusion_result else '❌'}")
        
        if all([ws_result.get('success'), html_result, fusion_result]):
            print("\n🎉 All tests passed! The karting system is ready.")
        else:
            print("\n⚠️ Some tests failed. Check the implementation.")
            
    except Exception as e:
        print(f"\n❌ Integration test failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())