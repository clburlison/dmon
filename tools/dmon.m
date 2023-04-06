#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#import <SpringBoardServices/SpringBoardServices.h>
#import <dlfcn.h>
#include <curl/curl.h>

// Get GoCheats version. Need to silence stderr. Popen might handle this for us.
// apt list | grep -i gocheats | cut -d ' ' -f 2
// Install with: appinst pogo.ipa

int killall(NSString *appName) {
    NSLog(@"dmon: Stopping appName: %@", appName);
    int stop_pid;
    char command[100]; // Make it large enough.
    sprintf(command, "killall %s", [appName UTF8String]);
    FILE *stop_pid_cmd = popen(command, "r");
    fscanf(stop_pid_cmd, "%d", &stop_pid);
    pclose(stop_pid_cmd);
    return stop_pid;
}

NSString * getFrontMostApplication() {
    mach_port_t p = SBSSpringBoardServerPort();
    char frontmostAppS[256];
    memset(frontmostAppS, 0, sizeof(frontmostAppS));
    SBFrontmostApplicationDisplayIdentifier(p, frontmostAppS);
    
    NSString * frontmostApp = [NSString stringWithFormat:@"%s", frontmostAppS];
    NSLog(@"dmon: Frontmost app is: %@", frontmostApp);
    return (frontmostApp);
}

int downloadFile(NSString *url, NSString *userpass, NSString *outfile) {
    CURL *curl;
    CURLcode res = -1;
    FILE *fp;
    curl = curl_easy_init();

    if (curl) {
        // Set the URL
        curl_easy_setopt(curl, CURLOPT_URL, [url UTF8String]);
        
        // Set the authentication headers
        curl_easy_setopt(curl, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_easy_setopt(curl, CURLOPT_USERPWD, [userpass UTF8String]);
        
        // Set the output file
        fp = fopen([outfile UTF8String], "wb");
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);

        // Perform the request
        res = curl_easy_perform(curl);
        NSLog(@"dmon: Curl return code for %@: %u", url, res);

        // Clean up
        fclose(fp);
        curl_easy_cleanup(curl);
    }
    return res;
}

void update(NSDictionary *config) {
    // Strip trailing forward slashes to make things consistent for users
    NSString *url = [config[@"dmon_url"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    NSLog(@"dmon: update URL is: %@", url);
    downloadFile(
        [NSString stringWithFormat:@"%@/version.txt", url],
        [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
        @"version.txt"
    );

    NSString *pogo_ipa = @"pogo.ipa";
    NSString *gc_deb = @"gc.deb";

    if (access([pogo_ipa UTF8String], F_OK) != 0) {
        NSLog(@"dmon: File does not exist. Let's download it");
        downloadFile(
            [NSString stringWithFormat:@"%@/%@", url, pogo_ipa],
            [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
            pogo_ipa
        );
    }
    if (access([gc_deb UTF8String], F_OK) != 0) {
        NSLog(@"dmon: File does not exist. Let's download it");
        downloadFile(
            [NSString stringWithFormat:@"%@/%@", url, gc_deb],
            [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
            gc_deb
        );
    }
}

void monitor(void) {
    NSString *currentApp = getFrontMostApplication();
    if (![currentApp isEqualToString:@"com.nianticlabs.pokemongo"]) {
        NSLog(@"dmon: Restarting Kernbypass...");
        killall(@"/usr/bin/kernbypass");
        NSLog(@"dmon: Force stopping Pogo...");
        killall(@"pokemongo");
        sleep(2);
        NSLog(@"dmon: Pogo not running. Launch it...");
        // Launch Pogo
        void* sbServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        int (*SBSLaunchApplicationWithIdentifier)(CFStringRef identifier, Boolean suspended) = dlsym(sbServices, "SBSLaunchApplicationWithIdentifier");
        NSString *bundleString=[NSString stringWithUTF8String:"com.nianticlabs.pokemongo"];
        int result = SBSLaunchApplicationWithIdentifier((__bridge CFStringRef)bundleString, NO);
        NSLog(@"dmon: Launch Pogo: %d", result);
        dlclose(sbServices);
    }
}

NSDictionary * parseConfig(void) {
    NSString *filePath = @"/var/mobile/Application Support/GoCheats/config.json";
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSError *error;
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:&error];

    if (fileData) {
        NSError *jsonError;
        NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:fileData options:NSJSONReadingMutableContainers error:&jsonError];
        
        if (jsonObject) {
            // Successfully parsed the JSON data
            return jsonObject;
        } else {
            // Failed to parse the JSON data
            NSLog(@"dmon: Error parsing JSON: %@", jsonError);
        }
    } else {
        // Failed to read the file data
        NSLog(@"dmon: Error reading file: %@", error);
    }
    return nil;
}

int main(void)
{
    NSDictionary *config = parseConfig();
    NSLog(@"dmon: Service setting: %@", config[@"dmon_enable"]);
    int i = 0;
    while ([config[@"dmon_enable"] boolValue]) {
        // Only call at the start of loop
        if (i == 0) {
            config = parseConfig();
            // NSLog(@"dmon: Our full config: %@", config);
            update(config);
        }

        // Call this function every loop
        monitor();

        // Restart loop on the 30th iteration
        if (++i == 30) {
            i = 0;
        }

        sleep(30);
    }
    return 0;
}
