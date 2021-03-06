//
//  ViewController.swift
//  Resistor
//
//  Created by Valitutto Giuseppe on 05/03/18.
//  Copyright © 2018 Team 5.2. All rights reserved.
//

import UIKit //fatto
import AVFoundation //fatto
import Vision //fatto
import CoreImage //fatti


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate { //fatto
    
    @IBOutlet weak var resultImageView: UIView!
    @IBOutlet weak var resultView: UIView!
        {
        didSet {
            self.resultView?.layer.cornerRadius = 10.0
//            self.resultView?.layer.masksToBounds = true
//            self.resultView?.clipsToBounds = true
            self.resultView?.layer.borderColor = UIColor.white.cgColor
            self.resultView?.layer.borderWidth = 3
        }
    }
    @IBOutlet weak var debugTextView: UITextView!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet private weak var highlightView: UIView!
    {
        didSet {
            self.highlightView?.layer.borderColor = UIColor.white.cgColor
            self.highlightView?.layer.borderWidth = 3
            self.highlightView?.backgroundColor = .clear
            self.highlightView?.layer.cornerRadius = 8.0
        }
    }
    
    private lazy var captureSession: AVCaptureSession = { //fatto
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard let backCamera = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: backCamera) else {
                return session
        }
        session.addInput(input)
        return session
    }() //fatto
    
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession) //fatto
    private var device: AVCaptureDevice =  AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)! // fatto !
    
    var videoPreviewLayer:AVCaptureVideoPreviewLayer? //fatto

    var visionRequests = [VNRequest]()
    private let context = CIContext()
    var imageCroppedGreen: CIImage!
    
    var viewWidth: CGFloat!
    var viewHeight: CGFloat!
    
    var imWorking = false
    
    override func viewDidLoad() { //fatto
        super.viewDidLoad() //fatto
        // Do any additional setup after loading the view, typically from a nib.
        
        //
        cameraLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill //fatto
        // make the camera appear on the screen
        self.cameraView?.layer.addSublayer(self.cameraLayer)
        
        let output = AVCaptureVideoDataOutput()//fatto
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "queue"))//fatto
        captureSession.addOutput(output)//fatto
        
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        /*
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)
        */
        
        // --- ML & Vision ---
        
        // Setup Vision Model
        guard let selectedModel = try? VNCoreMLModel(for: resistor_model().model) else {
            fatalError("Could not load model.")
        }
        // Set up Vision-CoreML Request
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
        
        // --- END ML & Vision ---
        
        // Start video capture.
        captureSession.startRunning()
        autofocusExposure()
        
        //orientamento dell'immagine
        guard let connection = output.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = AVCaptureDevice.Position.back == .front
        
        viewWidth = highlightView.bounds.width * UIScreen.main.scale //* highlightView.transform.a
        viewHeight = highlightView.bounds.height * UIScreen.main.scale //* highlightView.transform.d
        
        
        //Implementing gesture for flash on/off
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleGesture))
        swipeLeft.direction = .left
        self.view.addGestureRecognizer(swipeLeft)
        
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleGesture))
        swipeRight.direction = .right
        self.view.addGestureRecognizer(swipeRight)
        
        
        
    }
    
    // ----- FLASH
    @IBOutlet weak var torchButton: UIButton!
    @IBAction func enableFlash(_ sender: UIButton)
        {
            if (device.hasTorch) {
                do {
                    
                    try device.lockForConfiguration()
                        if (device.isTorchActive == false)
                        {
                            
                            device.torchMode = .on
                            sender.setBackgroundImage(UIImage(named: "flash-on"), for: UIControlState.normal)
                            try device.setTorchModeOn(level: 1.0)
                        }
                        else
                        {
                            device.torchMode = .off
                            sender.setBackgroundImage(UIImage(named: "flash-off"), for: UIControlState.normal)
                            
                        }
                    device.unlockForConfiguration()
                }
                catch {
                    print(error)
                }
            }
    }
        

    
    //gesture function
    @objc func handleGesture(gesture: UISwipeGestureRecognizer) -> Void {
        if (device.hasTorch) {
            do {
                try device.lockForConfiguration()
                switch gesture.direction
                {
                case UISwipeGestureRecognizerDirection.right:
                    device.torchMode = .on
                    torchButton.setBackgroundImage(UIImage(named: "flash-on"), for: UIControlState.normal)
                    try device.setTorchModeOn(level: 1.0)
                    break
                case UISwipeGestureRecognizerDirection.left:
                    device.torchMode = .off
                    torchButton.setBackgroundImage(UIImage(named: "flash-off"), for: UIControlState.normal)
                    break
                default:
                    break
                }
                device.unlockForConfiguration()
            }
            catch {
                print(error)
            }
            
        }
    }
    
    //---- FLASH END
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // make sure the layer is the correct size
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBOutlet weak var imageViewCropped: UIImageView!
    var c = 0
    var c1 = 0
    var croppedCII: CIImage!
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        //      richiamato per ogni frame
        c += 1
        //      guard let pixelBuffet: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        //      let ciImage = CIImage(cvPixelBuffer: pixelBuffet)
        //        let cropped = ciImage.cropped(to: CGRect(origin: view.center, size: CGSize(width: 400.0, height: 200.0)))
        
        //execute func defined at the end of the code
        guard let croppedCGI = getImageFromSampleBuffer(buffer: sampleBuffer) else { return }
        
        croppedCII = CIImage(cgImage: croppedCGI)
        
        
        //Remove/add comment if you want view how it's displayed dropped camera
        //         DispatchQueue.main.async { [unowned self] in
        
        //execute func defined at the end of the code
        //            self.imageViewCropped.image = self.convert(cmage: self.croppedCII)
        //           self.imageViewCropped.center = self.view.center
        //         }
        
        if(c >= 10 && !imWorking){
            c1 += 1
            //          print("entrato \(c1)")
            
            // Prepare CoreML/Vision Request
            let imageRequestHandler = VNImageRequestHandler(ciImage: croppedCII, options: [:])
            
            // Run Vision Image Request
            do {
                try imageRequestHandler.perform(self.visionRequests)
            } catch {
                print(error)
            }
            
            c = 0;
        }
        
        
    }
    
    
    
    // MARK: - MACHINE LEARNING
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get Classifications
        let classifications = observations[0...1] // top 2 results
            .flatMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        // Render Classifications
        DispatchQueue.main.async {
            // Display Debug Text on screen
            self.debugTextView.text = classifications
        }
        
        let topPrediction = classifications.components(separatedBy: "\n")[0]
        let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
        // Only display a prediction if confidence is above 1%
        let topPredictionScore:Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
        if (topPredictionScore != nil && topPredictionScore! > 0.01) {
            if (topPredictionName == "resistenza" && topPredictionScore! > 0.50) {
                //                    metodo di esempio per il passaggio dell'immagine
                //                    faccio un clone dell'immagine perchè non sono sicuro...
                
                
                //locco perchè sto lavorando, che ti pensi ue
                self.imWorking = true
                
                //var to store image cropped that have prediction > 0.50
                self.imageCroppedGreen = self.croppedCII
                
                let filter = AdaptiveThreshold()
                let image =  self.convert(cmage: self.croppedCII)
                filter.inputImage = CIImage(image: image, options: [kCIImageColorSpace: NSNull()])
                
                let final = filter.outputImage!
                
                let uiimage = self.convert(cmage: final)
                
                DispatchQueue.main.async {
                    self.highlightView?.layer.borderColor = UIColor.green.cgColor
					//set the imageGroppedgreen in the view imageViewCropped
					//self.imageViewCropped.image = self.convert(cmage: self.imageCroppedGreen)
                    
                    self.imageViewCropped.image = uiimage
                    
//                    let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
//                    tap.numberOfTapsRequired = 2
//                    self.view.addGestureRecognizer(tap)
                }
                
                print("convert ciao")
//                let ciao = self.convert(cmage: self.imageCroppedGreen)
                
                let width = Int(uiimage.size.width)
                let height = Int(uiimage.size.height)
                
                var array = Array<CatchedPoint>()
                
                print("final = \(final)")
                
                //elaboro pixel per pixel facendo la media dei colori per colonna
                for pixel in 0..<width{
//                    print("elaboro pixel \(pixel)")
//                    let rect = CGRect(x: pixel, y: 0, width: 1, height: height)
//                    let rect = CGRect(x: pixel, y: 0, width: 1, height: height)
                    let rect = CGRect(x: pixel, y: (height - 60 / 2) / 2, width: 1, height: 60)
                    
                    if let currentFilter = CIFilter(name: "CIColumnAverage") {
//                        print(final.cropped(to: rect))
                        currentFilter.setValue(final.cropped(to: rect), forKey: kCIInputImageKey)
//                        currentFilter.setValue(0.5, forKey: kCIInputIntensityKey)
//                            currentFilter.setValue(0, forKey: kCIInputSaturationKey)

                        if let output = currentFilter.outputImage {
//                            print(output)
                            if output.extent.isEmpty { print("empty"); continue }
//                            print("convert color")
                            let current = CatchedPoint()
                            current.color = self.getPixelColor(image: self.convert(cmage: output), pos: CGPoint(x: 0, y: 0))
                            
                            if(pixel == 0){
                                current.minPoint = pixel
                                array.append(current)
                            }
                            
                            let distance = sqrtf(powf((Float((array.last?.color!.red)! - current.color.red)), 2) + powf((Float((array.last?.color!.green)! - current.color.green)), 2) + powf((Float((array.last?.color!.blue)! - current.color.blue)), 2) );
//                            print(distance)
                            // valore da impostare per la distanza fra i colori
                            if(distance > 0.4){
                                array.last?.maxPoint = pixel - 1
                                current.minPoint = pixel
                                array.append(current)
                            }
                            /*
                             if let cgimg = self.context.createCGImage(output, from: output.extent) {
                             self.imageViewCropped.image = self.convert(cmage: output)
                             let processedImage = UIImage(cgImage: cgimg)
                             // do something interesting with the processed image
                             }
                             */
                        }
                    }
                }
                
                array.last?.maxPoint = width - 1
                
                print("array length \(array.count)")
                
                /*
                DispatchQueue.main.async {
                    
                    for (index, color) in array.enumerated() {
                        print("metto colore")
                        var imageView = UIImageView(image: self.convert(cmage: self.croppedCII))
                        imageView.backgroundColor = UIColor(ciColor: color)
                        imageView.tintColor = UIColor(ciColor: color)
                        imageView.frame = CGRect(x: 320 * CGFloat(index), y: 0, width: 320, height: 130)
                        self.view.addSubview(imageView)
                        sleep(1)
                    }
                }

                 */
                
                DispatchQueue.main.async {
                    self.resultImageView.subviews.forEach({ $0.removeFromSuperview() })
                }
                
//                cattura dei colori dall'immagine colorata senza applicazione di filtri

                for (catchedIndex, catchedPoint) in array.enumerated() {
                    
//                    catchedPoint.color
                    let distanceToBlack = sqrtf(powf((Float((catchedPoint.color.red) - 0)), 2) + powf((Float((catchedPoint.color.green) - 0)), 2) + powf((Float((catchedPoint.color.blue) - 0)), 2))
                    
                    if distanceToBlack > 1.0 { continue }
                    
                    let point = (catchedPoint.maxPoint + catchedPoint.minPoint) / 2
                    
//                    let rect = CGRect(x: point, y: 0, width: 1, height: height)
//                    let rect = CGRect(x: point, y: 0, width: 1, height: height)
                    let rect = CGRect(x: point, y: (height - 60 / 2) / 2, width: 1, height: 60)
                    
                    if let currentFilter = CIFilter(name: "CIColumnAverage") {
                        currentFilter.setValue(self.imageCroppedGreen.cropped(to: rect), forKey: kCIInputImageKey)
//                        currentFilter.setValue(0.5, forKey: kCIInputIntensityKey)
//                            currentFilter.setValue(0, forKey: kCIInputSaturationKey)
                        
                        if let output = currentFilter.outputImage {
                            if output.extent.isEmpty { continue }
                            let uiimage = self.convert(cmage: output)

                            DispatchQueue.main.async {
                                let imageView = UIImageView(image: uiimage)
                                imageView.frame = CGRect(x: catchedIndex * 10, y: 0, width: 50, height: 50)
                                self.resultImageView.addSubview(imageView)
                            }
                        }
                    }
                    
                }
                
                DispatchQueue.main.async {
                    self.imageViewCropped.image = self.convert(cmage: self.imageCroppedGreen)
                }
//                finito di lavorare
                self.imWorking = false
                
            } else {
                DispatchQueue.main.async {
                    self.highlightView?.layer.borderColor = UIColor.white.cgColor
                }
            }
            if (topPredictionName == "noresistenza") { }
        }
        
        //self.textOverlay.text = symbol
    }
    
    func toHexString(color: UIColor) -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return NSString(format:"#%06x", rgb) as String
    }
    
    func getPixelColor(image: UIImage, pos: CGPoint) -> CIColor {
        
        let pixelData = image.cgImage?.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let pixelInfo: Int = ((Int(image.size.width) * Int(pos.y)) + Int(pos.x)) * 4
        
        let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
        let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
        let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)
        
        return CIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    
    
    //FILTER NOISE REDUCTION FUNCTION
    func filterImage(image: CIImage) -> CIImage? {
        
        let filter = CIFilter(name: "CINoiseReduction")!
        filter.setValue(0.03, forKey: "inputNoiseLevel")
        filter.setValue(0.60, forKey: "inputSharpness")
        filter.setValue(image, forKey: kCIInputImageKey)
        let result = filter.outputImage!
        return result
    }
    
    @objc func handleTap(gesture: UITapGestureRecognizer) {
        
        //solo per test, da rimuovere - salva il file all'interno della galleria
        print("Double tap pressed")
        
        sleep(1)
        let image = self.imageViewCropped.image!
        var i = CGFloat(0)
        var j = CGFloat(0)
        let k = CGFloat(3)
        print("Image size width: \(image.size.width)")
        print("Image size height: \(image.size.height)")
        
        
        while(i <= (image.size.width - image.size.width/k)){
            print("Value of i: \(i)")
            while(j <= (image.size.height - image.size.height/k)){
                print("Value of j: \(j)")
//                let rect = CGRect(x: i, y: j , width: (image.size.width)/k, height: (image.size.height)/k)
//                let cropped = self.imageCroppedGreen.cropped(to: rect)
//                let croppedUI = self.convert(cmage: cropped)
//
//                UIImageWriteToSavedPhotosAlbum(croppedUI, nil, nil, nil)
                j = j + (image.size.height)/(k*3)
                
            }
            print("")
            j = CGFloat(0)
            
            i = i + (image.size.width)/(k*3)
            
        }
        
        //fine test
    }
    
    //    messa a fuoco
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let screenSize = cameraView.bounds.size
        if let touchPoint = touches.first {
            let x = touchPoint.location(in: cameraView).y / screenSize.height
            let y = 1.0 - touchPoint.location(in: cameraView).x / screenSize.width
            let focusPoint = CGPoint(x: x, y: y)
            
            let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            if let device = captureDevice {
                do {
                    try device.lockForConfiguration()
                    
                    device.focusPointOfInterest = focusPoint
                    //device.focusMode = .continuousAutoFocus
                    device.focusMode = .autoFocus
                    //device.focusMode = .locked
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
                    device.unlockForConfiguration()
                }
                catch {
                    // just ignore
                }
            }
        }
    }
    
    var pivotPinchScale: CGFloat!
    
    @IBAction func pinchToZoom(_ sender: UIPinchGestureRecognizer) {
        do {
            try device.lockForConfiguration()
            switch sender.state {
            case .began:
                self.pivotPinchScale = device.videoZoomFactor
            case .changed:
                var factor = self.pivotPinchScale * (sender.scale * 1.2)
                factor = max(1, min(factor, device.activeFormat.videoMaxZoomFactor))
                device.videoZoomFactor = factor
            default:
                break
            }
            device.unlockForConfiguration()
        } catch {
            // handle exception
        }
    }
    
    // Convert CIImage to UImage
    func convert(cmage:CIImage) -> UIImage
    {
//        print(cmage)
//        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    //autofocus and autoexposure
    func autofocusExposure()
    {
        do {
            try device.lockForConfiguration()
            device.focusMode = AVCaptureDevice.FocusMode.autoFocus
            device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
            device.unlockForConfiguration()
        } catch {
            // handle exception
        }
    }
        
    

    
    //get CGImage from CMSampleBuffer
    func getImageFromSampleBuffer (buffer:CMSampleBuffer) -> CGImage? {
        
        if(viewHeight == nil) { return nil }
        
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
            let uiImage = UIImage(cgImage: cgImage!)
            
            let rect = CGRect(x: (uiImage.size.width - viewWidth) / 2, y: (uiImage.size.height - viewHeight / 2) / 2, width: viewWidth, height: viewHeight)
            
            let cropped = ciImage.cropped(to: rect)
            
            //          let context = CIContext()
            if let image = context.createCGImage(cropped, from: cropped.extent) {
                return image
            }
        }
        return nil
    }
    

    
}

