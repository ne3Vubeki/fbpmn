export 'indexed_db_service_base.dart';

import 'indexed_db_service_base.dart';
import 'indexed_db_service_stub.dart'
    if (dart.library.js_interop) 'indexed_db_service_wasm.dart'
    if (dart.library.html) 'indexed_db_service_web.dart';

IndexedDbService createIndexedDbService() => createIndexedDbServiceImpl();
