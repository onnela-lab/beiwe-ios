// Populate your own sentry credentials here, it is your call on whether to commit them to your repo.
// You can populate both values, with the same DSN, but it is useful to have one
// for purely-development versions, and one for app store releases.
//
// Sentry DSNs look like this:  "https://xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx@oyyyyy.ingest.sentry.io/zzzzz"


struct SentryKeys {
    static var development_dsn = ""
    static var release_dsn     = ""
}
