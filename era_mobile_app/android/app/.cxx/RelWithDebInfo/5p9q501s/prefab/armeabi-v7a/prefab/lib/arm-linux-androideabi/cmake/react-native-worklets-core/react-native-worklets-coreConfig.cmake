if(NOT TARGET react-native-worklets-core::rnworklets)
add_library(react-native-worklets-core::rnworklets SHARED IMPORTED)
set_target_properties(react-native-worklets-core::rnworklets PROPERTIES
    IMPORTED_LOCATION "/home/mic/learn/era/era_mb_game/era_mobile_app/node_modules/react-native-worklets-core/android/build/intermediates/cxx/RelWithDebInfo/3d4z506d/obj/armeabi-v7a/librnworklets.so"
    INTERFACE_INCLUDE_DIRECTORIES "/home/mic/learn/era/era_mb_game/era_mobile_app/node_modules/react-native-worklets-core/android/build/headers/rnworklets"
    INTERFACE_LINK_LIBRARIES ""
)
endif()

