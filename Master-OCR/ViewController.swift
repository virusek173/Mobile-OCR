//
//  ViewController.swift
//  Master-OCR
//
//  Created by Jacek Graczyk on 27/08/2020.
//  Copyright © 2020 Jacek Graczyk. All rights reserved.
//

import UIKit
import MobileCoreServices
import Vision
import TesseractOCR
import GPUImage
import MLKitVision
import MLKitTextRecognition
//import Collection

//import TextRecognition

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var mainTextView: UITextView!
    @IBOutlet weak var mainImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func addPhotoClicked(_ sender: Any) {
        let imagePickerActionSheet =
            UIAlertController(title: "Take or Upload Image",
                              message: nil,
                              preferredStyle: .actionSheet)
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let cameraButton = UIAlertAction(
                title: "Take Photo",
                style: .default) { (alert) -> Void in
                    self.activityIndicator.startAnimating()
                    let imagePicker = UIImagePickerController()
                    imagePicker.delegate = self
                    imagePicker.sourceType = .camera
                    self.present(imagePicker, animated: true, completion: {
                        self.activityIndicator.stopAnimating()
                    })
            }
            imagePickerActionSheet.addAction(cameraButton)
        }
        
        let libraryButton = UIAlertAction(
            title: "Choose Photo",
            style: .default) { (alert) -> Void in
                self.activityIndicator.startAnimating()
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .photoLibrary
                self.present(imagePicker, animated: true, completion: {
                    self.activityIndicator.stopAnimating()
                })
        }
        imagePickerActionSheet.addAction(libraryButton)
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel)
        imagePickerActionSheet.addAction(cancelButton)
        
        present(imagePickerActionSheet, animated: true)
    }
    
    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage! {
        let context = CIContext(options: nil)
        
        if let contextCreate = context.createCGImage(inputImage, from: inputImage.extent) {
            return contextCreate
        }
        
        return nil
    }
    
    func performVisionFrameworkRecognition(_ image: UIImage) {
        if #available(iOS 13.0, *) {
            var sumTime = 0.0
            let itetationNumer = 1
            for i in 0..<itetationNumer {
                self.mainTextView.text = ""
                let start = DispatchTime.now()
                let ciImage = CIImage(image: image)!
                let cgImage = self.convertCIImageToCGImage(inputImage: ciImage)!
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNRecognizeTextRequest {(request, error) in
                    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                    
                    for currentObservation in observations {
                        let topCandidate = currentObservation.topCandidates(1)
                        if let recognizedText = topCandidate.first {
                            
                            self.mainTextView.text += "\n"
                            self.mainTextView.text += recognizedText.string
                            print(recognizedText.string)
                        }
                    }
                }
                
                request.recognitionLevel = .accurate
                let languageArray = try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: VNRequestTextRecognitionLevel.fast, revision: 1)
                
                print("languageArray: ", languageArray ?? [])
                
                
                try? requestHandler.perform([request])
                
                let end = DispatchTime.now()
                let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
                let timeInterval = Double(nanoTime) / 1_000_000_000
                sumTime += timeInterval
                print("Iteration: \(i) time: \(timeInterval)")
            }
            
            let meanTime: Double = sumTime/Double(itetationNumer)
            
            print("meanTime: \(meanTime)")
            
            activityIndicator.stopAnimating()
        }
    }
    
    // Tesseract Image Recognition
    func performTesseractRecognition(_ image: UIImage) {
        guard let scaledImage = image.scaledImage(1000) else { return }
        guard let preprocessedImage = scaledImage.preprocessedImage() else { return }
        
        //        mainImageView.image = preprocessedImage
        //        activityIndicator.stopAnimating()
        //        return
        
        let start = DispatchTime.now()
        
        if let tesseract = G8Tesseract(language: "eng") {
            tesseract.engineMode = .tesseractCubeCombined
            tesseract.pageSegmentationMode = .auto
            tesseract.image = preprocessedImage
            tesseract.recognize()
            self.mainTextView.text = tesseract.recognizedText
        }
        activityIndicator.stopAnimating()
        
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        
        print("time: \(timeInterval)")
    }
    
    // ML Kit Image Recognition
    func performMLKitRecognition(_ image: UIImage) {
        guard let scaledImage = image.scaledImage(1280) else { return }
        
        print("scaledImage dimentions: \(scaledImage.size)")

        let start = DispatchTime.now()
        self.mainTextView.text = ""
        
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        let textRecognizer = TextRecognizer.textRecognizer()
        
        textRecognizer.process(visionImage) { result, error in
          guard error == nil, let result = result else {
            print("Error: \(error ?? "no err mess" as! Error)")
            return
          }
            
            var lines: [String] = []
            var yArray: [CGFloat] = []
            for block in result.blocks {
                for line in block.lines {
                    let lineText = line.text
                    let lineFrame = line.frame
                    let midY = lineFrame.midY
                    lines.append(lineText)
                    yArray.append(midY)
                }
            }
            let indexes = self.argsort(arrayToSort: yArray)
            for index in indexes {
                let reconizedText = "\(lines[index]) \n"
                self.mainTextView.text += reconizedText
                print(reconizedText)
            }
            
            self.activityIndicator.stopAnimating()
            
            let end = DispatchTime.now()
            let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000_000
            
            print("time: \(timeInterval)")
        }
        print("end of the function!")
    }
    
    func argsort( arrayToSort: [CGFloat] ) -> [Int] {
        let sorted = arrayToSort.enumerated().sorted(by: {$0.element < $1.element})
        let justIndices = sorted.map{$0.offset}
        
        return justIndices
    }

    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let selectedPhoto = info[.originalImage] as? UIImage else {
            dismiss(animated: true)
            return
        }
        activityIndicator.startAnimating()
        dismiss(animated: true) {
//            self.performVisionFrameworkRecognition(selectedPhoto)
//            self.performTesseractRecognition(selectedPhoto)
            self.performMLKitRecognition(selectedPhoto)
        }
    }
}

extension UIImage {
    func scaledImage(_ maxDimension: CGFloat) -> UIImage? {
        var scaledSize = CGSize(width: maxDimension, height: maxDimension)
        
        if size.width > size.height {
            scaledSize.height = size.height / size.width * scaledSize.width
        } else {
            scaledSize.width = size.width / size.height * scaledSize.height
        }
        
        UIGraphicsBeginImageContext(scaledSize)
        draw(in: CGRect(origin: .zero, size: scaledSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    func preprocessedImage() -> UIImage? {
        let stillImageFilter = GPUImageAdaptiveThresholdFilter()
        stillImageFilter.blurRadiusInPixels = 1
        let filteredImage = stillImageFilter.image(byFilteringImage: self)
        return filteredImage
    }
}

