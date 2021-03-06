NSURLConnectionVCR
==================

`NSURLConnectionVCR` provides an easy way to record and re-play `NSURLConnection` requests/responses.
By removing the dependency on external web servers, your tests will run fast and deterministic.
Don't worry, no need to change your existing `NSURLConnection`-based code.
`NSURLConnectionVCR` hooks into `NSURLConnection` by 'swizzling' implementations at run-time.

This project is inspired on [Myron Marston's VCR for Ruby on Rails] [1].

Getting Started
---------------

First, start the VCR and give it a storage path:

	[NSURLConnectionVCR startVCRWithPath:@"fixtures/vcr_cassettes" error:nil];

Then perform a request using `NSURLConnection`:

	NSURL* url = [NSURL URLWithString:@"http://api.example.com/fancy.json"];
	NSURLRequest* request = [NSURLRequest requestWithURL:url];
    NSHTTPURLResponse* response = nil;
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];

The first time this code is run, it will run the request and store the response in a file at the specified path.
Run it again, and VCR will 'play back' the recorded response from disk, without making a call to the web server.

Optionally, stop the VCR once you're done:

	[NSURLConnection stopVCRWithError:nil];

Adding NSURLConnectionVCR to your project
-----------------------------------------

Requirements:

* Mac OS X 10.7 SDK or later
* iOS 5.0 SDK or later
* ARC (Automatic Reference Counting)

Just add `NSURLConnectionVCR.m` and `NSURLConnectionVCR.h` to your project.
There are no external dependencies, except of course Foundation.framework and the Objective C runtime.

Quicklook plug-in
-----------------

`NSURLConnectionVCR` creates one file per unique request and stores it at the specified path.
The provided Quicklook plug-in makes basic inspection of these cache files convenient.
A cache file is basically an archive containing the `NSURLResponse` and `NSData` that were returned when the request was done.
The name of the cache file is the MD5 digest of the original `NSURLRequest`.
The Quicklook preview displays the response data and puts the original URL and HTTP status code as title of the preview window.

[1]: https://www.relishapp.com/myronmarston/vcr