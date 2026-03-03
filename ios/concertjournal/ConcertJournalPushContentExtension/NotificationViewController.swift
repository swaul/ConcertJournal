//
//  NotificationViewController.swift
//  ConcertJournalPushContentExtension
//
//  Created by Paul Arbetit on 27.02.26.
//

import UIKit
import UserNotificationsUI
import UserNotifications
import UIKit

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
    
    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let userName = content.userInfo["sender_name"] as? String ?? "Unknown"
        let message = content.body
        
        var image: UIImage?
        if let attachment = content.attachments.first {
            image = UIImage(contentsOfFile: attachment.url.path)
        }
        
        // Custom View erstellen
        let customView = CustomNotificationView(
            image: image,
            userName: userName,
            message: message
        )
        
        view.addSubview(customView)
        customView.frame = view.bounds
    }
}

// Dein Custom UIView
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
