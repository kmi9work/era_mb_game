if(NOT TARGET react-native-vision-camera::VisionCamera)
add_library(react-native-vision-camera::VisionCamera SHARED IMPORTED)
set_target_properties(react-native-vision-camera::VisionCamera PROPERTIES
    IMPORTED_LOCATION "/home/mic/learn/era/era_mb_game/era_mobile_app/node_modules/react-native-vision-camera/android/build/intermediates/cxx/RelWithDebInfo/543g4c41/obj/x86/libVisionCamera.so"
    INTERFACE_INCLUDE_DIRECTORIES "/home/mic/learn/era/era_mb_game/era_mobile_app/node_modules/react-native-vision-camera/android/build/headers/visioncamera"
    INTERFACE_LINK_LIBRARIES ""
)
endif()

