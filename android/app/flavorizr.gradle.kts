import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor")

    productFlavors {
        create("dev") {
            dimension = "flavor"
            applicationId = "com.exe.schedula.dev"
            resValue(type = "string", name = "app_name", value = "Schedula Dev")
        }
        create("staging") {
            dimension = "flavor"
            applicationId = "com.exe.schedula.staging"
            resValue(type = "string", name = "app_name", value = "Schedula Staging")
        }
        create("prod") {
            dimension = "flavor"
            applicationId = "com.exe.schedula"
            resValue(type = "string", name = "app_name", value = "Schedula")
        }
    }

    buildFeatures.resValues = true
}