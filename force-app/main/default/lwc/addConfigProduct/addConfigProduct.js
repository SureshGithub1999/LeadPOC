import { LightningElement, api, track } from 'lwc';
import getInitData from '@salesforce/apex/AddConfigProductController.getInitData';
import getFieldsForProductType from '@salesforce/apex/AddConfigProductController.getFieldsForProductType';
import createProductAndOLI from '@salesforce/apex/AddConfigProductController.createProductAndOLI';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class AddConfigProduct extends LightningElement {

    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        console.log('SETTER recordId:', value);
        this._recordId = value;
        if (value) {
            this.loadInitData();
        }
    }

    @track loading = true;
    @track dynamicFields = [];
    @track fieldValues = {};
    @track totalPrice = 0;


    productTypeOptions = [];
    selectedProductType = '';
    quantity = 1;
    listPrice = 0;
    salesPrice = 0;


    connectedCallback() {
        console.log('connectedCallback recordId=', this._recordId);
    }

    async loadInitData() {
        try {
            console.log('Loading init for opp:', this._recordId);
            this.loading = true;

            const data = await getInitData({ opportunityId: this._recordId });
            console.log('INIT DATA:', data);

            this.productTypeOptions = data.productTypeOptions;
        } catch (e) {
            this.showError(e);
        } finally {
            this.loading = false;
        }
    }

    async handleTypeChange(event) {
        this.selectedProductType = event.detail.value;
        console.log('Selected type:', this.selectedProductType);

        try {
            this.loading = true;
            const fields = await getFieldsForProductType({
                productTypeDevName: this.selectedProductType
            });

            console.log('FIELDSET RECEIVED:', fields);

            this.dynamicFields = fields.map(f => ({
                ...f,
                value: f.defaultValue || ''
            }));

            this.fieldValues = {};
            this.dynamicFields.forEach(f => {
                this.fieldValues[f.apiName] = f.value;
            });

        } catch (e) {
            this.showError(e);
        } finally {
            this.loading = false;
        }
    }

    handleFieldChange(event) {
        const api = event.target.dataset.field;
        this.fieldValues[api] = event.target.value;

        this.dynamicFields = this.dynamicFields.map(f =>
            f.apiName === api ? { ...f, value: event.target.value } : f
        );
    }

    handleQtyChange(event) {
    this.quantity = Number(event.target.value || 1);
    this.calculateTotal();
}

    async handleSubmit() {
        try {
            this.loading = true;

            const payload = {
    opportunityId: this._recordId,
    productTypeDevName: this.selectedProductType,
    fieldValues: this.fieldValues,
    quantity: this.quantity,
    listPrice: this.listPrice,
    salesPrice: this.salesPrice
};



            await createProductAndOLI({
                payloadJson: JSON.stringify(payload)
            });

            this.showToast('Success', 'Product added successfully!', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());

        } catch (e) {
            this.showError(e);
        } finally {
            this.loading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }


handleSalesPriceChange(event) {
    this.salesPrice = Number(event.target.value || 0);
    this.calculateTotal();
}

calculateTotal() {
    this.totalPrice = this.salesPrice * this.quantity;
}


    showError(e) {
        const msg = e?.body?.message || e.message || JSON.stringify(e);
        this.showToast('Error', msg, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}