import { LightningElement, api, track } from 'lwc';
import getFileDetails from '@salesforce/apex/FileUploadController.getFileDetails';
import deleteFile from '@salesforce/apex/FileUploadController.deleteFile';

export default class FileUploadPreview extends LightningElement {
    @api recordId;
    @track fileList = [];

    formatSize(size) {
        if (size < 1024) {
            return `${size} bytes`;
        } else if (size < 1024 * 1024) {
            return `${(size / 1024).toFixed(2)} KB`;
        } else {
            return `${(size / (1024 * 1024)).toFixed(2)} MB`;
        }
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        const docIds = uploadedFiles.map(f => f.documentId);

        // Call Apex to get size + type
        getFileDetails({ documentIds: docIds }).then(details => {
            details.forEach(d => {
                this.fileList = [
                    ...this.fileList,
                    {
                        title: d.Title,
                        documentId: d.ContentDocumentId,
                        size: this.formatSize(d.ContentSize),
                        fileType: d.FileType,
                        downloadUrl:
                            `/sfc/servlet.shepherd/document/download/${d.ContentDocumentId}`
                    }
                ];
            });
        });
    }

    handleDelete(event) {
        const docId = event.target.dataset.id;

        deleteFile({ contentDocumentId: docId })
            .then(() => {
                this.fileList = this.fileList.filter(f => f.documentId !== docId);
            })
            .catch(error => console.error(error));
    }
}