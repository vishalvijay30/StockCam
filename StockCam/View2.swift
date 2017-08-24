//
//  View2.swift
//  StockCam
//
//  Created by Vishal  on 8/7/17.
//
//

import UIKit
import AVFoundation
import SwiftyJSON

class View2: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let session = URLSession.shared
    
    var image : UIImage?
    var captureSession : AVCaptureSession?
    var stillImageOutput : AVCaptureStillImageOutput?
    var previewLayer : AVCaptureVideoPreviewLayer?

    @IBOutlet weak var cameraView: UIView!
    
    var googleAPIKey = "AIzaSyDPxcJyGQOvNMP4wxvSF7OJUI7hhPjIv7w"
    var googleURL : URL {
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer?.frame = cameraView.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080
        
        let backCamera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        var errorThrown : NSError?
        var input : AVCaptureDeviceInput?
        do {
            input = try AVCaptureDeviceInput(device: backCamera)
        } catch {
            errorThrown = error as NSError?
        }
        
        if errorThrown == nil && (captureSession?.canAddInput(input))! {
            captureSession?.addInput(input)
            
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput?.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]
            
            if (captureSession?.canAddOutput(stillImageOutput))! {
                captureSession?.addOutput(stillImageOutput)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
                previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.portrait
                if let unwrappedPreviewLayer = previewLayer {
                    cameraView.layer.addSublayer(unwrappedPreviewLayer)
                }
                captureSession?.startRunning()
            }
        }
    }
    @IBOutlet weak var tempImageView: UIImageView!
    
    func didPressTakePhoto() {
        //var image : UIImage?
        if let videoConnection = stillImageOutput?.connection(withMediaType: AVMediaTypeVideo) {
            videoConnection.videoOrientation = AVCaptureVideoOrientation.portrait
            stillImageOutput?.captureStillImageAsynchronously(from: videoConnection, completionHandler: {
                (sampleBuffer, error) in
                
                if sampleBuffer != nil {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    let dataProvider = CGDataProvider(data: imageData as! CFData)
                    let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
                    
                    self.image = UIImage(cgImage: cgImageRef!, scale: 1.0, orientation: UIImageOrientation.right)
                    
                    
                    self.tempImageView.isHidden = false
                    self.tempImageView.image = self.image
                    self.view.addSubview(self.tempImageView)
                }
            })
        }
        print("captured image: \(self.image)")
    }
    
    var didTakePhoto = Bool()
    
    func didPressTakeAnother() {
        //var image : UIImage?
        if didTakePhoto == true {
            tempImageView.isHidden = true
            didTakePhoto = false
            //return nil
        } else {
            captureSession?.startRunning()
            didTakePhoto = true
            didPressTakePhoto()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        didPressTakeAnother()
        if let unwrappedImage = self.image {
            let binaryImage = encodeImageBase64(image: unwrappedImage)
            createRequest(with: binaryImage)
        }
        //didPressTakeAnother()
    }
//*****************************************************************************************************//
    
    //Networking
    func encodeImageBase64(image : UIImage) -> String {
        var imageData = UIImagePNGRepresentation(image)
        
        //resize image if it exceeds API size limit
        if ((imageData?.count)! > 2097152) {
            let oldSize : CGSize = image.size
            let newSize: CGSize = CGSize(width: 800, height: oldSize.height / oldSize.width * 800)
            imageData = resizeImage(imageSize: newSize, image: image)
        }
        
        return imageData!.base64EncodedString(options: .endLineWithCarriageReturn)
    }
    
    func createRequest(with imageBase64 : String) {
        print("reached here")
        //create request URL
        var request = URLRequest(url: googleURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        //request.addValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        
        //Build API request
        let jsonRequest = [
            "requests": [
                "image": [
                    "content": imageBase64
                ],
                "features": [
                    [
                        "type": "LOGO_DETECTION",
                        "maxResults": 10
                    ]
                ]
            ]
        ]
        
        let jsonObject = JSON(jsonDictionary : jsonRequest)
        
        //Serialize the JSON
        guard let data = try? jsonObject.rawData() else {
            return
        }
        
        request.httpBody = data
        
        // Run the request on a background thread
        DispatchQueue.global().async { self.runRequestOnBackgroundThread(_request: request) }
    }
    
    func runRequestOnBackgroundThread(_request : URLRequest) {
        let task: URLSessionDataTask = session.dataTask(with: _request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "")
                return
            }
            
            self.analyzeResults(dataToParse : data)
        }
        
        task.resume()
    }
//*****************************************************************************************************//
    
    //Image Processing
    func resizeImage(imageSize : CGSize, image : UIImage) -> Data {
        UIGraphicsBeginImageContext(imageSize)
        image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        let resizedImage = UIImagePNGRepresentation(newImage!)
        UIGraphicsEndImageContext()
        return resizedImage!
    }
    
    func analyzeResults(dataToParse : Data) {
        //Update UI on main thread
        DispatchQueue.main.async(execute: {
            //parse results
            let json = JSON(data : dataToParse)
            let errorObj : JSON = json["error"]
            
            //TODO: display
            
            if (errorObj.dictionaryValue != [:]) {
                print("Error code \(errorObj["code"]): \(errorObj["message"])")
            } else {
                print(json)
                let responses : JSON = json["responses"][0]
                
                //Get logo annotations
                let logoAnnotations : JSON = responses["logoAnnotations"]
                let numLogos : Int = logoAnnotations.count
                
                if numLogos > 0 {
                    print(logoAnnotations[0]["description"].stringValue)
                } else {
                    print("No logos detected")
                }
            }
        })
    }
}
