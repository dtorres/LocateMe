//////////////////////////////////////////////////////////////
// (CC) Diego Torres, warorface.com                         //
// 2010 - http://creativecommons.org/licenses/by-nc-sa/3.0/ //
//////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>
#import "JSON.h"

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//Creating a new Task to invoke a new list of Access Points
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"];
    NSArray *arguments;
    arguments = [NSArray arrayWithObjects: @"-x", @"-s", nil];
    [task setArguments: arguments];
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    [task launch];
    NSData *data;
    data = [file readDataToEndOfFile];
	
	NSString *errorDesc = nil;
	NSPropertyListFormat format;
	//Handling the Obtained Data as a Property List in a new Dictionary
	NSDictionary * dict = (NSDictionary*)[NSPropertyListSerialization
										  propertyListFromData:data
										  mutabilityOption:NSPropertyListMutableContainersAndLeaves
										  format:&format
										  errorDescription:&errorDesc];
	
	//If we were unable to get the Dictionary it means there is no Wi-Fi
	if (!dict) {
		printf("Unable to get Location, make sure your Airport Card (Wi-Fi) is on\n");
		exit(0);
	} else {
		//Now lets transform the information in a JSON to send it to Google
		NSMutableArray *json_aps = [[NSMutableArray alloc] init]; //(empty) List of Access Points in JSON
		//For each Access Point in the Dictionary(dict) as a new Dictionary(nsdict)
		for (NSDictionary *nsdict in dict) {
			NSString *ssid = [nsdict objectForKey:@"SSID_STR"]; //Lets get the AP Name
			NSArray *mac_array = [[nsdict objectForKey:@"BSSID"] componentsSeparatedByString:@":"]; //Getting each Hex of the Mac address in an Array to avoid bad formating with 0 left.
			
			NSMutableArray *parsed_mac = [[NSMutableArray alloc] init]; //the final Mac Address
			//Lets check each Hex for faulty ones and fill it with a 0
			for (NSString *hex in mac_array) {
				if ([hex length] <= 2) {
					NSString *newhex = [[@"" stringByPaddingToLength:2 - [hex length] withString:@"0" startingAtIndex:0] stringByAppendingString:hex];
					[parsed_mac addObject:newhex];
				} else {
					[parsed_mac addObject:hex];
				}
			}
			NSString *channel = [nsdict objectForKey:@"CHANNEL"]; //Getting the Channel
			NSString *signal_to_noise = [nsdict objectForKey:@"NOISE"]; //The Noise level
			NSString *signal_strength = [nsdict objectForKey:@"RSSI"]; //The Signal Strength
			//Now lets build a new JSON array and add it to the product.
			NSString *json_str =[NSString stringWithFormat:@"{\"mac_address\": \"%@\", \"channel\": %@, \"signal_to_noise\": %@, \"signal_strength\": %@, \"ssid\": \"%@\"}", [parsed_mac componentsJoinedByString:@"-"], channel, signal_to_noise, signal_strength, ssid];
			[json_aps addObject:json_str];
		}
		//The final JSON string and send it to Google via POST method
		NSString *output = [NSString stringWithFormat:@"{ 'version': '1.1.0', 'host': 'http://www.warorface.com', 'request_address': true, 'wifi_towers': [ %@ ] }", [json_aps componentsJoinedByString:@", "]];
		NSData *postData = [output dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
		
		NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
		[request setURL:[NSURL URLWithString:@"http://www.google.com/loc/json"]];
		[request setHTTPMethod:@"POST"];
		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		[request setHTTPBody:postData];
		NSURLResponse *resp = nil;
		NSError *err = nil;
		//Lets get the response
		NSData *response = [NSURLConnection sendSynchronousRequest: request returningResponse: &resp error: &err];
		NSString * theString = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
		// Create SBJSON object to parse JSON
		SBJSON *parser = [[SBJSON alloc] init];
		// parse the JSON string into an object - assuming json_string is a NSString of JSON data (it should be)
		NSDictionary *object = [parser objectWithString:theString error:nil];
		NSDictionary *location = [object objectForKey:@"location"];
		// Getting the needed Values
		NSString *lat = [[location objectForKey:@"latitude"] stringValue];
		NSString *lng = [[location objectForKey:@"longitude"] stringValue];
		NSString *accr = [[location objectForKey:@"accuracy"] stringValue];
		//Now lets output them
		printf("Your Location is:\n");
		printf("	Latitude: %s.\n", [lat UTF8String]);
		printf("	Longitude: %s.\n", [lng UTF8String]);
		printf("	Range of Accuracy: %s Meters.\n", [accr UTF8String]);
	}
    [pool drain];
    return 0;
}