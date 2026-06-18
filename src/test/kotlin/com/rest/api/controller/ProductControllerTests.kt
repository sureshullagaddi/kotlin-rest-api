package com.rest.api.controller

import com.rest.api.entity.Product
import com.rest.api.service.ProductService
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.BeforeEach
import org.mockito.Mockito.*
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.mock.mockito.MockBean
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*
import java.math.BigDecimal
import java.time.LocalDateTime

@SpringBootTest
@AutoConfigureMockMvc
class ProductControllerTests {

    @Autowired
    private lateinit var mockMvc: MockMvc

    @MockBean
    private lateinit var productService: ProductService

    private lateinit var testProduct: Product

    @BeforeEach
    fun setUp() {
        testProduct = Product(
            id = 1L,
            name = "Test Product",
            price = BigDecimal("99.99"),
            createdAt = LocalDateTime.now(),
            updatedAt = LocalDateTime.now()
        )
    }

    @Test
    fun `GET all products should return 200 OK`() {
        `when`(productService.getAllProducts()).thenReturn(listOf(testProduct))

        mockMvc.perform(get("/api/products"))
            .andExpect(status().isOk)
            .andExpect(content().contentType(MediaType.APPLICATION_JSON))
            .andExpect(jsonPath("$[0].id").value(1))
            .andExpect(jsonPath("$[0].name").value("Test Product"))
    }

    @Test
    fun `GET product by ID should return 200 OK`() {
        `when`(productService.getProductById(1L)).thenReturn(testProduct)

        mockMvc.perform(get("/api/products/1"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.name").value("Test Product"))
    }

    @Test
    fun `GET product by non-existent ID should return 404`() {
        `when`(productService.getProductById(999L)).thenReturn(null)

        mockMvc.perform(get("/api/products/999"))
            .andExpect(status().isNotFound)
    }

    @Test
    fun `POST create product should return 201 CREATED`() {
        `when`(productService.createProduct(any())).thenReturn(testProduct)

        mockMvc.perform(
            post("/api/products")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"Test Product","price":99.99}""")
                .with { it.userPrincipal = null; it }  // Mock auth
        )
            .andExpect(status().isCreated)
            .andExpect(jsonPath("$.id").value(1))
    }

    @Test
    fun `PUT update product should return 200 OK`() {
        `when`(productService.updateProduct(eq(1L), any())).thenReturn(testProduct)

        mockMvc.perform(
            put("/api/products/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"Updated Product","price":199.99}""")
                .with { it.userPrincipal = null; it }
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(1))
    }

    @Test
    fun `DELETE product should return 204 NO CONTENT`() {
        doNothing().`when`(productService).deleteProduct(1L)

        mockMvc.perform(
            delete("/api/products/1")
                .with { it.userPrincipal = null; it }
        )
            .andExpect(status().isNoContent)
    }

    @Test
    fun `Search product by name should return 200 OK`() {
        `when`(productService.getProductByName("Test Product")).thenReturn(testProduct)

        mockMvc.perform(get("/api/products/search/by-name?name=Test Product"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.name").value("Test Product"))
    }
}

