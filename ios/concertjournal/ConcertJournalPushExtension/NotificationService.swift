import UserNotifications
import UIKit

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }
        
        // Avatar URL aus Payload holen
        guard let avatarUrlString = request.content.userInfo["sender_avatar_url"] as? String,
              let avatarUrl = URL(string: avatarUrlString)
        else {
            contentHandler(content)
            return
        }
        
        // Bild herunterladen
        downloadImage(from: avatarUrl) { attachment in
            if let attachment {
                content.attachments = [attachment]
            }
            contentHandler(content)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func downloadImage(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        URLSession.shared.downloadTask(with: url) { location, _, error in
            guard let location, error == nil else {
                completion(nil)
                return
            }
            
            // Temp-Datei mit richtiger Extension
            let tmpUrl = location.deletingLastPathComponent()
                .appendingPathComponent(location.lastPathComponent + ".jpg")
            try? FileManager.default.moveItem(at: location, to: tmpUrl)
            
            let attachment = try? UNNotificationAttachment(
                identifier: "avatar",
                url: tmpUrl,
                options: nil
            )
            completion(attachment)
        }.resume()
    }
}

class CustomNotificationView: UIView {
    init(image: UIImage?, userName: String, message: String) {
        super.init(frame: .zero)
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 25
        
        let nameLabel = UILabel()
        nameLabel.text = userName
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .gray
        
        // Stack aufbauen und constraints setzen...
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
