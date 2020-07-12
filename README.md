# FMZDropInMinimalFacebookLogin

Not yet production tested but a very simple minimal replacement for the Facebook SDK that is not just a privacy
monster but capable of bringing half the apps on the planet to a crashing halt at launch. It should also reduce app
download sizes by some megabytes.

Feature set is limited to logging in and out in a very similar way to the FacebookSDKs plus basic GraphRequest
functionality although that GraphRequest feature has not been tested in any way at all at the point of committing it but it
builds and launches in a project I tried it in with these additional features/tweaks.

Naming is because I don't like Mark Zuckerburg.

It depends only on iOS frameworks, no third party packages but you do need to inject some closures to make it functional.

# How it works

It uses an ASWebAuthenticationSession for an nice experience on iOS 12+ and falls back to pushing to a web browser
and back for lower versions*.

* Lower version support not tested on hardware. Problems in simulator on iOS 10 but working well on iOS 11.

# Credits
Thanks to @marinbenc for his article [Implementing Facebook Login on iOS without Facebook SDK](https://dev.to/marinbenc/implementing-facebook-login-on-ios-without-facebook-sdk-3k05)
on which this development was based.

Thanks also to the Facebook Ops teams whose recent outage triggerings have given me great hope that I can persuade clients
to remove the Facebook SDK from Apps for the privacy benefit of the users, to ease my conscience having integrated it for them
in the first place and 

# Setup and use

0. Review this code, its only 4 files totally about 270 lines at the time of writing this initial ReadMe so make sure that you
are comfortable.
1. Remove Facebook SDKs from your project
2. Add this Swift Package to you project and target
3. Remove import statements for FacebookCore and FacebookLogin (you could wrap this package in an empty one
of your own providing it in one or both of these if they are massively used throughout the code base and you want
absolute minimum code changes). Replace them with `import FMZDropInMinimalFacebookLogin`
4. Remove call to Facebook's application(didFinishLaunching..) function in your App Delegate and configure this framework
instead:
```swift
MinimalFacebook.currentConfig =
    MinimalFacebook.Config(
        getTokenStringFromKeychain: { keyChain.getString(key: "FacebookLoginTokenString") },
        setTokenStringToKeychain: {
            if let token = $0 {
                _ = keyChain.setString(token, key: "FacebookLoginTokenString")
            } else {
                keyChain.removeString(key: "FacebookLoginTokenString")
            }
        },
        openUrl: { UIApplication.shared.open($0, options: [:]) })
```
Optionally but recommended you should check that tokens are still valid for logged in users. This runs that in 10s so that it happens
after all you initial launch logic. It will invalidate the token if the user has been logged out.
```
if AccessToken.current != nil {
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        MinimalFacebook.validateCurrentToken()
    }
}
```
You need to provide closures to openUrls (for iOS 9,10,11) and also to read and write to the keychain (because the Apple APIs
are clunky and I didn't want to add another dependency when you already likely have wrappers in your project). The
`setTokenStringToKeyChain` closure should remove the value when a nil argument is passed in. 
5. Build and see if it has everything that you use. It may build and run correctly at first use.
6. If it doesn't run you may have some fix up to do. Some types may have changed so it may be that you can remove
some explicit types. You may also be using features that are not supported in this. In which case some reimplementation
may be needed.

# Potential / Known Issues

On iOS 10 in the Simulator login was failing as the app was not reopening with the URL. I have not investigated deeply, user
base on iOS shoud be pretty low at this point.

# PRs and Updates
I'm definitely interested in any fixes and also compatibility enhancing updates. Initially I've developed it against the needs
of a single project and if some minor additions help others that would be great but I do want to keep it minimal for small app
size and for reviewability.

# Tests

Feel free to write some. The tricky bits are integration with the app launch and with the Facebook server so the necessary tests
aren't obvious to me. But please do try out all scenarios you can think of and feel free to let me know.

# Contact

I'm @jl_hfl on Twitter, let me know what you think. Please boycott and defund Facebook as much as possible. This is intended
to be a tool to help people and apps migrate away and I'm keen to support if you are using it in that context.
