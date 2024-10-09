import CouchbaseLiteSwift
import Foundation
import ObjectMapper

// its a key that we need to use to access something about the database metadata
let kReclineMetadataKey = "reclineMetadata"

// Any call into json.map can error with an invalid collection count, which can't be caught.
// This error still happens inside _save(), even though _save() is only called from save()
// on a dedicated DispatchQueue called OUTER_RECLINE_QUEUE that wraps save, purge, and compact.
// (and now I've added open and queryall so that's what we are currently testing I guess)
// How the hell is this happening? is ObjectMapper just bugged?

// This class name is utter, absolute, complete, and total garbage.
/// A database ~manager class for CouchbaseLite
class Recline {
    static let shared = Recline()  // singleton instance

    var db: Database?

    /// trivial init - possibly to keep db access as a singleton via open maybe?
    init() {}

    /// database open function - called exactly once in AppDelegate
    /// this function only be called once at app instantiation. If this fails, the app fails.
    /// Sets self.db, self.typesView; defines view functions - whatever that means.
    func open(_ dbName: String = "default") {
        OUTER_RECLINE_QUEUE.sync {
            self._open(dbName)
        }
    }

    func _open(_ dbName: String = "default") {
        if self.db == nil {
            do {
                self.db = try Database(name: dbName)
            } catch {
                fatalError("Error opening database")
            }
        }
    }

    /// Save database changes. Template type is ObjectMapper types, mostly surevy and study, studysettings
    // todo: let's get a comprehensive list of types passed in here
    func save<T: ReclineObject>(_ obj: T) {
        OUTER_RECLINE_QUEUE.sync {
            return _save(obj)
        }
    }

    func _save<T: ReclineObject>(_ obj: T) {
        // give up early if db is not instantiated
        guard let db = self.db else {
            fatalError(
                "again the database is not instantiated - what do you think you are doing?"
            )
        }
        // get or create the document.  I can't tell if this could be made non-optional,
        var doc: MutableDocument?
        if let _id = obj._id {
            do {
                doc = try db.defaultCollection().document(id: _id)?.toMutable()
            } catch {
                fatalError("no doc found")
            }
        } else {
            doc = MutableDocument()
        }
        // take the object, make a json version of it, and .... then we do something involving ReclineMetadata?
        var newProps: [String: Any] = Mapper<T>().toJSON(obj)
        let reclineMeta = ReclineMetadata(
            type: String(describing: type(of: obj)))
        newProps[kReclineMetadataKey] = Mapper<ReclineMetadata>().toJSON(
            reclineMeta)

        for (key, value) in newProps {
            doc?.setValue(value, forKey: key)
        }

        do {
            if let doc = doc {
                try db.defaultCollection().save(document: doc)
                print(
                    "Created document id type \(doc.id)? with patientId = \(doc.string(forKey: "patientId")!)"
                )
            } else {
                fatalError("Failed to create or fetch the document for saving")
            }
        } catch {
            fatalError("cannot save document")
        }
    }

    /// gets all rows in the typesView database view?
    // runs the query across everything and returns the contents.
    func queryAll<T: ReclineObject>() -> [T] {
        OUTER_RECLINE_QUEUE.sync {
            return self._queryAll()
        }
    }

    func _queryAll<T: ReclineObject>() -> [T] {
        guard let db = self.db else {
            fatalError("uh, you didn't open the database?")
        }
        // create an unfiltered query, run it, iterate on rows, each row is a study
        let query =
            QueryBuilder
            .select(
                SelectResult.expression(Meta.id),
                SelectResult.all()
            )
            .from(DataSource.collection(try! db.defaultCollection()))

        var loadedObjects: [T] = []

        for result in try! query.execute() {
            guard let docId = result.string(forKey: "id"),
                let dct =
                    (result.value(forKey: "_default") as? DictionaryObject)?
                    .toDictionary(),
                let jsonData = try? JSONSerialization.data(
                    withJSONObject: dct, options: [])
            else {
                continue
            }

            if let jsonString = String(data: jsonData, encoding: .utf8),
                let rObj = Mapper<T>().map(JSONString: jsonString)
            {
                rObj._id = docId
                loadedObjects.append(rObj)
            }

            if let jsonString = String(data: jsonData, encoding: .utf8),
                let rObj = Mapper<T>().map(JSONString: jsonString)
            {
                rObj._id = docId
                loadedObjects.append(rObj)
            }
        }

        return loadedObjects
    }

    // purges document from database...?
    func purge<T: ReclineObject>(_ obj: T) {
        OUTER_RECLINE_QUEUE.sync {
            return _purge(obj)
        }
    }

    func _purge<T: ReclineObject>(_ obj: T) {
        guard let db = self.db else {
            fatalError("what are you doing the database isn't instantiated")
        }

        if let object_id = obj._id {
            do {
                let doc = try db.defaultCollection().document(id: object_id)
                try db.defaultCollection().delete(document: doc!)
            } catch {
                fatalError("error purging document: \(error)")
            }
        }
    }

    /// runs the database compact operation (why? we have a TINY database.)
    func compact() {
        OUTER_RECLINE_QUEUE.sync {
            // no available compact function on the newest version of couchbase
        }
    }
}

/// class for objects returned from a database query
class ReclineObject: Mappable {
    fileprivate var _id: String?
    init() {}
    required init?(map: Map) {}
    func mapping(map: Map) {}  // Mappable
}

/// I don't know. Usage doesn't obviously mean anything to me other than it has a type value that is set.
struct ReclineMetadata: Mappable {
    var type: String?
    init?(map: Map) {}
    init(type: String) {
        self.type = type
    }

    mutating func mapping(map: Map) {
        self.type <- map["type"]
    }
}
