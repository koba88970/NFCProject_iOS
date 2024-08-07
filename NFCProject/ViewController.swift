import UIKit
import CoreNFC
import AVFoundation

class ViewController: UIViewController, NFCNDEFReaderSessionDelegate {

    var nfcSession: NFCNDEFReaderSession?
    var audioPlayer: AVAudioPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // "audio"を含むWAVファイルのパスを設定します
        guard let path = Bundle.main.path(forResource: "audio", ofType:"wav") else {
            print("Audio file not found")
            return
        }

        let url = URL(fileURLWithPath: path)

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            print("Could not load file")
        }
    }

    @IBAction func startWriting(_ sender: Any) {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "エラー",
                message: "このデバイスはNFCをサポートしていません。",
                preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "NFCタグに書き込む準備ができています。"
        nfcSession?.begin()
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // セッションが無効になったときの処理
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // NDEFメッセージを検出したときの処理
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            session.alertMessage = "複数のタグが検出されました。1つのタグをスキャンしてください。"
            DispatchQueue.main.async {
                session.invalidate()
                self.nfcSession?.begin()
            }
            return
        }

        guard let tag = tags.first else { return }
        session.connect(to: tag) { (error: Error?) in
            if let error = error {
                session.alertMessage = "接続に失敗しました。再試行してください。"
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }

            self.writeURL(to: tag, session: session)
            self.audioPlayer?.play()  // WAVファイルを再生
        }
    }

    func writeURL(to tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        let urlString = "https://example.com/audio.mp3"  // この部分は適宜変更してください
        guard let urlPayload = NFCNDEFPayload.wellKnownTypeURIPayload(url: URL(string: urlString)!) else { return }
        let ndefMessage = NFCNDEFMessage(records: [urlPayload])

        tag.queryNDEFStatus { (status, capacity, error) in
            if status == .readWrite {
                tag.writeNDEF(ndefMessage) { (error: Error?) in
                    if let error = error {
                        session.alertMessage = "書き込みに失敗しました。"
                        session.invalidate(errorMessage: error.localizedDescription)
                    } else {
                        session.alertMessage = "書き込みが成功しました！"
                        session.invalidate()
                    }
                }
            } else {
                session.alertMessage = "このタグには書き込めません。"
                session.invalidate()
            }
        }
    }
}

