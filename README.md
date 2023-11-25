# ClarifEye

An iOS app to help those with visual impairment identify objects when navigating outdoor spaces.

It performs the following:

- Accesses phone camera
- Performs classification on identified objects
- Predicts distance of identified objects

## Setup

1. Download FCRN Model from https://developer.apple.com/machine-learning/models/ and our object identification model. You can use `YOLOv3` as well for setup.
2. Add the `.mlmodel`s as files into the XCode project under the `Models` folder
3. Connect iPhone and run!
