#Garzon: Leaves of the Philippine Tree Classification
# 🌿 Garzon: Leaves of the Philippine Tree Classification

This project is a **leaf-image classification system** developed to identify various Philippine tree species based on leaf photographs.  
Developed by Reha Mae Garzon, this is the final project for classifying nine native/common Philippine trees.

---

## 🌳 Classified Tree Types  
The system currently classifies the following 9 species:  
1. Bamboo  
2. Banana  
3. Coconut  
4. Guava  
5. Jackfruit  
6. Mahogany  
7. Mango  
8. Narra  
9. Papaya

---

## 🧠 Project Overview  
- A machine learning model was trained on labeled images of leaves for the species listed above.  
- The model outputs predictions (via a .tflite file) and stores classification results.  
- The repository includes model evaluation artifacts (accuracy graphs, confusion matrix) and the production model file (`model_unquant.tflite`).

---

## 📦 Included Files & Folders  
- **Accuracy per epoch.png**, **Loss per epoch.png** – model training graphs  
- **Confusion Matrix.png**, **Accuracy per class.png** – detailed performance visuals  
- **model_unquant.tflite** – the converted TFLite model ready for deployment  
- **labels.txt** – list of class labels in order used by the model  
- Output images (`Output-1.png`, `Output-2.png`, …) – example predictions / visual results  
- Source code (backend + frontend) – for uploading a leaf image and receiving a predicted class

---

## 🛠 Tech Stack   
- **Machine Learning:** Python (TensorFlow or equivalent)  
- **Model Deployment:** TensorFlow Lite (.tflite)  
- **Tools:** Git & GitHub

---

## ⚙️ Setup & Installation

1. Clone the repository  
   ```bash
   git clone https://github.com/rheamae20/Garzon_LeavesofthePhilippineTree_Classification_FinalProject.git
